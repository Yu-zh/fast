// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// The Llama-architecture forward pass (after llama2.c), composing the kernels
// in `kernels.mbt`: token embedding -> N decoder layers (RMSNorm -> RoPE
// self-attention with a KV cache and grouped-query support -> RMSNorm ->
// SwiGLU feed-forward, each with a residual) -> final RMSNorm -> logits. f32
// weights are supplied per layer so each `matmul` reads a contiguous matrix.

///|
/// Model hyper-parameters.
pub(all) struct Config {
  dim : Int
  hidden_dim : Int
  n_layers : Int
  n_heads : Int
  n_kv_heads : Int
  vocab_size : Int
  seq_len : Int
}

///|
/// Model weights. Per-layer matrices are stored one `FixedArray` per layer
/// (row-major), so a layer's matrix feeds `matmul` directly.
pub(all) struct Weights {
  token_embedding : FixedArray[Float] // (vocab, dim)
  rms_att : Array[FixedArray[Float]] // per layer: (dim)
  wq : Array[FixedArray[Float]] // per layer: (dim, dim)
  wk : Array[FixedArray[Float]] // per layer: (kv_dim, dim)
  wv : Array[FixedArray[Float]] // per layer: (kv_dim, dim)
  wo : Array[FixedArray[Float]] // per layer: (dim, dim)
  rms_ffn : Array[FixedArray[Float]] // per layer: (dim)
  w1 : Array[FixedArray[Float]] // gate, per layer: (hidden_dim, dim)
  w2 : Array[FixedArray[Float]] // down, per layer: (dim, hidden_dim)
  w3 : Array[FixedArray[Float]] // up,   per layer: (hidden_dim, dim)
  rms_final : FixedArray[Float] // (dim)
  wcls : FixedArray[Float] // (vocab, dim)
}

///|
/// Per-run scratch buffers and the autoregressive KV cache.
pub(all) struct RunState {
  x : FixedArray[Float]
  xb : FixedArray[Float]
  xb2 : FixedArray[Float]
  hb : FixedArray[Float]
  hb2 : FixedArray[Float]
  q : FixedArray[Float]
  k : FixedArray[Float]
  v : FixedArray[Float]
  att : FixedArray[Float]
  logits : FixedArray[Float]
  key_cache : FixedArray[Float]
  value_cache : FixedArray[Float]
}

///|
pub(all) struct Transformer {
  config : Config
  weights : Weights
  state : RunState
}

///|
fn zeros(n : Int) -> FixedArray[Float] {
  FixedArray::make(n, 0.0)
}

///|
/// Allocates a transformer (and its scratch/KV state) from a config and
/// weights.
pub fn Transformer::new(config : Config, weights : Weights) -> Transformer {
  let dim = config.dim
  let kv_dim = dim * config.n_kv_heads / config.n_heads
  let state = RunState::{
    x: zeros(dim),
    xb: zeros(dim),
    xb2: zeros(dim),
    hb: zeros(config.hidden_dim),
    hb2: zeros(config.hidden_dim),
    q: zeros(dim),
    k: zeros(kv_dim),
    v: zeros(kv_dim),
    att: zeros(config.n_heads * config.seq_len),
    logits: zeros(config.vocab_size),
    key_cache: zeros(config.n_layers * config.seq_len * kv_dim),
    value_cache: zeros(config.n_layers * config.seq_len * kv_dim),
  }
  Transformer::{ config, weights, state }
}

///|
/// Runs one decoding step for `token` at sequence position `pos`, updating the
/// KV cache, and returns the logits over the vocabulary (a borrow of internal
/// state — copy it if you need to keep it across calls).
pub fn Transformer::forward(
  self : Transformer,
  token : Int,
  pos : Int,
) -> FixedArray[Float] {
  let c = self.config
  let w = self.weights
  let s = self.state
  let dim = c.dim
  let head_size = dim / c.n_heads
  let kv_dim = dim * c.n_kv_heads / c.n_heads
  let kv_mul = c.n_heads / c.n_kv_heads
  let scale = (1.0 : Float) / fsqrt(Float::from_int(head_size))

  // token embedding -> x
  for i in 0..<dim {
    s.x[i] = w.token_embedding[token * dim + i]
  }
  for l in 0..<c.n_layers {
    // attention block
    rmsnorm(s.xb, s.x, w.rms_att[l], dim)
    matmul(s.q, s.xb, w.wq[l], dim, dim)
    matmul(s.k, s.xb, w.wk[l], dim, kv_dim)
    matmul(s.v, s.xb, w.wv[l], dim, kv_dim)
    rope(s.q, s.k, pos, dim, kv_dim, head_size)
    // append k, v to the cache at this position
    let loff = l * c.seq_len * kv_dim
    for i in 0..<kv_dim {
      s.key_cache[loff + pos * kv_dim + i] = s.k[i]
      s.value_cache[loff + pos * kv_dim + i] = s.v[i]
    }
    // per-head scaled-dot-product attention over cached keys/values
    for h in 0..<c.n_heads {
      let qoff = h * head_size
      let head_off = h / kv_mul * head_size
      let attoff = h * c.seq_len
      for t in 0..<=pos {
        let kcoff = loff + t * kv_dim + head_off
        s.att[attoff + t] = dot(s.q, qoff, s.key_cache, kcoff, head_size) *
          scale
      }
      softmax(s.att, attoff, pos + 1)
      for i in 0..<head_size {
        s.xb[qoff + i] = 0.0
      }
      for t in 0..<=pos {
        let vcoff = loff + t * kv_dim + head_off
        let a = s.att[attoff + t]
        for i in 0..<head_size {
          s.xb[qoff + i] = s.xb[qoff + i] + a * s.value_cache[vcoff + i]
        }
      }
    }
    // output projection + residual
    matmul(s.xb2, s.xb, w.wo[l], dim, dim)
    for i in 0..<dim {
      s.x[i] = s.x[i] + s.xb2[i]
    }
    // feed-forward (SwiGLU) + residual
    rmsnorm(s.xb, s.x, w.rms_ffn[l], dim)
    matmul(s.hb, s.xb, w.w1[l], dim, c.hidden_dim)
    matmul(s.hb2, s.xb, w.w3[l], dim, c.hidden_dim)
    swiglu(s.hb, s.hb2, c.hidden_dim)
    matmul(s.xb, s.hb, w.w2[l], c.hidden_dim, dim)
    for i in 0..<dim {
      s.x[i] = s.x[i] + s.xb[i]
    }
  }
  // final norm + classifier
  rmsnorm(s.x, s.x, w.rms_final, dim)
  matmul(s.logits, s.x, w.wcls, dim, c.vocab_size)
  s.logits
}
