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

// INT8 group quantization (after llama2.c's `runq`). Each contiguous group of
// GS values shares one float scale: `q = round(v / scale)`, `scale = max|v| /
// 127`. The quantized matmul reads int8 weights — 4x less memory than f32, the
// real bottleneck — and, because int8 *does* have a vector load (unlike typed
// float arrays), it finally uses true SIMD: `v128_load` + `i32x4_dot_i16x8_s`.
// GS = 16, so every group is exactly one 16-byte vector load.

///|
const GS = 16

///|
/// A matrix quantized to int8 with one float scale per group of GS.
pub(all) struct QTensor {
  q : FixedArray[Byte] // int8 values (two's complement)
  scales : FixedArray[Float] // one per group
}

///|
fn iround(x : Float) -> Int {
  if x >= (0.0 : Float) {
    (x + (0.5 : Float)).to_int()
  } else {
    (x - (0.5 : Float)).to_int()
  }
}

///|
fn fabs(x : Float) -> Float {
  if x < (0.0 : Float) {
    -x
  } else {
    x
  }
}

///|
/// Quantizes `src[soff..soff+n]` (n a multiple of GS) into the int8 buffer `q`
/// at `qoff` and the per-group `scales` at `goff`.
fn quantize_into(
  src : FixedArray[Float],
  soff : Int,
  n : Int,
  q : FixedArray[Byte],
  qoff : Int,
  scales : FixedArray[Float],
  goff : Int,
) -> Unit {
  let groups = n / GS
  for g in 0..<groups {
    let base = soff + g * GS
    let mut amax = (0.0 : Float)
    for i in 0..<GS {
      let a = fabs(src[base + i])
      if a > amax {
        amax = a
      }
    }
    let scale = amax / (127.0 : Float)
    scales[goff + g] = scale
    let inv = if scale > (0.0 : Float) {
      (1.0 : Float) / scale
    } else {
      (0.0 : Float)
    }
    for i in 0..<GS {
      let v = iround(src[base + i] * inv)
      let c = if v > 127 { 127 } else if v < -127 { -127 } else { v }
      q[qoff + g * GS + i] = (c & 0xff).to_byte()
    }
  }
}

///|
/// Quantizes a flat `total`-element weight matrix (total a multiple of GS).
pub fn quantize_matrix(w : FixedArray[Float], total : Int) -> QTensor {
  let q : FixedArray[Byte] = FixedArray::make(total, 0)
  let scales : FixedArray[Float] = FixedArray::make(total / GS, 0.0)
  quantize_into(w, 0, total, q, 0, scales, 0)
  QTensor::{ q, scales }
}

///|
/// Quantized matrix-vector product: `out = W @ x`, where `W` is `d` rows of
/// length `n` quantized in `w`, and `x` is given pre-quantized as int8 `xq`
/// with per-group scales `xs`. `n` must be a multiple of GS. The inner int8
/// dot uses real vector loads + `i32x4_dot_i16x8_s`, scaled back to float per
/// group.
pub fn qmatmul(
  out : FixedArray[Float],
  xq : FixedArray[Byte],
  xs : FixedArray[Float],
  w : QTensor,
  n : Int,
  d : Int,
) -> Unit {
  let groups = n / GS
  for i in 0..<d {
    let row = i * n
    let rowg = i * groups
    let mut val = (0.0 : Float)
    let mut g = 0
    while g < groups {
      let wv = @v128.v128_load(w.q, row + g * GS)
      let xv = @v128.v128_load(xq, g * GS)
      let s = @v128.i32x4_add(
        @v128.i32x4_dot_i16x8_s(
          @v128.i16x8_extend_low_i8x16_s(wv),
          @v128.i16x8_extend_low_i8x16_s(xv),
        ),
        @v128.i32x4_dot_i16x8_s(
          @v128.i16x8_extend_high_i8x16_s(wv),
          @v128.i16x8_extend_high_i8x16_s(xv),
        ),
      )
      let ival = (@v128.i32x4_extract_lane(s, 0) +
      @v128.i32x4_extract_lane(s, 1) +
      @v128.i32x4_extract_lane(s, 2) +
      @v128.i32x4_extract_lane(s, 3)).reinterpret_as_int()
      val = val + Float::from_int(ival) * w.scales[rowg + g] * xs[g]
      g = g + 1
    }
    out[i] = val
  }
}

///|
/// Quantized model weights: norms and the token embedding stay f32; every
/// matmul weight is an int8 `QTensor`.
pub(all) struct QWeights {
  token_embedding : FixedArray[Float]
  rms_att : Array[FixedArray[Float]]
  wq : Array[QTensor]
  wk : Array[QTensor]
  wv : Array[QTensor]
  wo : Array[QTensor]
  rms_ffn : Array[FixedArray[Float]]
  w1 : Array[QTensor]
  w2 : Array[QTensor]
  w3 : Array[QTensor]
  rms_final : FixedArray[Float]
  wcls : QTensor
}

///|
pub(all) struct QTransformer {
  config : Config
  weights : QWeights
  state : RunState
  xq : FixedArray[Byte] // scratch: quantized activation
  xs : FixedArray[Float] // scratch: activation scales
}

///|
fn quantize_layers(
  ws : Array[FixedArray[Float]],
  per_total : Int,
) -> Array[QTensor] {
  let out : Array[QTensor] = []
  for w in ws {
    out.push(quantize_matrix(w, per_total))
  }
  out
}

///|
/// Builds a quantized transformer from full-precision `weights` by quantizing
/// every matmul matrix (norms and embedding kept f32). Requires `dim` and
/// `hidden_dim` to be multiples of GS (16).
pub fn QTransformer::new(config : Config, weights : Weights) -> QTransformer {
  let dim = config.dim
  let hidden_dim = config.hidden_dim
  let kv_dim = dim * config.n_kv_heads / config.n_heads
  let qweights = QWeights::{
    token_embedding: weights.token_embedding,
    rms_att: weights.rms_att,
    wq: quantize_layers(weights.wq, dim * dim),
    wk: quantize_layers(weights.wk, kv_dim * dim),
    wv: quantize_layers(weights.wv, kv_dim * dim),
    wo: quantize_layers(weights.wo, dim * dim),
    rms_ffn: weights.rms_ffn,
    w1: quantize_layers(weights.w1, hidden_dim * dim),
    w2: quantize_layers(weights.w2, dim * hidden_dim),
    w3: quantize_layers(weights.w3, hidden_dim * dim),
    rms_final: weights.rms_final,
    wcls: quantize_matrix(weights.wcls, config.vocab_size * dim),
  }
  let state = RunState::{
    x: FixedArray::make(dim, 0.0),
    xb: FixedArray::make(dim, 0.0),
    xb2: FixedArray::make(dim, 0.0),
    hb: FixedArray::make(hidden_dim, 0.0),
    hb2: FixedArray::make(hidden_dim, 0.0),
    q: FixedArray::make(dim, 0.0),
    k: FixedArray::make(kv_dim, 0.0),
    v: FixedArray::make(kv_dim, 0.0),
    att: FixedArray::make(config.n_heads * config.seq_len, 0.0),
    logits: FixedArray::make(config.vocab_size, 0.0),
    key_cache: FixedArray::make(config.n_layers * config.seq_len * kv_dim, 0.0),
    value_cache: FixedArray::make(
      config.n_layers * config.seq_len * kv_dim,
      0.0,
    ),
  }
  QTransformer::{
    config,
    weights: qweights,
    state,
    xq: FixedArray::make(hidden_dim, 0),
    xs: FixedArray::make(hidden_dim / GS, 0.0),
  }
}

///|
/// Runs one quantized decoding step for `token` at position `pos`, returning
/// the logits. Same Llama decoder as `Transformer::forward`, but every matmul
/// is int8.
pub fn QTransformer::forward(
  self : QTransformer,
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
  for i in 0..<dim {
    s.x[i] = w.token_embedding[token * dim + i]
  }
  for l in 0..<c.n_layers {
    rmsnorm(s.xb, s.x, w.rms_att[l], dim)
    quantize_into(s.xb, 0, dim, self.xq, 0, self.xs, 0)
    qmatmul(s.q, self.xq, self.xs, w.wq[l], dim, dim)
    qmatmul(s.k, self.xq, self.xs, w.wk[l], dim, kv_dim)
    qmatmul(s.v, self.xq, self.xs, w.wv[l], dim, kv_dim)
    rope(s.q, s.k, pos, dim, kv_dim, head_size)
    let loff = l * c.seq_len * kv_dim
    for i in 0..<kv_dim {
      s.key_cache[loff + pos * kv_dim + i] = s.k[i]
      s.value_cache[loff + pos * kv_dim + i] = s.v[i]
    }
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
    quantize_into(s.xb, 0, dim, self.xq, 0, self.xs, 0)
    qmatmul(s.xb2, self.xq, self.xs, w.wo[l], dim, dim)
    for i in 0..<dim {
      s.x[i] = s.x[i] + s.xb2[i]
    }
    rmsnorm(s.xb, s.x, w.rms_ffn[l], dim)
    quantize_into(s.xb, 0, dim, self.xq, 0, self.xs, 0)
    qmatmul(s.hb, self.xq, self.xs, w.w1[l], dim, c.hidden_dim)
    qmatmul(s.hb2, self.xq, self.xs, w.w3[l], dim, c.hidden_dim)
    swiglu(s.hb, s.hb2, c.hidden_dim)
    quantize_into(s.hb, 0, c.hidden_dim, self.xq, 0, self.xs, 0)
    qmatmul(s.xb, self.xq, self.xs, w.w2[l], c.hidden_dim, dim)
    for i in 0..<dim {
      s.x[i] = s.x[i] + s.xb[i]
    }
  }
  rmsnorm(s.x, s.x, w.rms_final, dim)
  quantize_into(s.x, 0, dim, self.xq, 0, self.xs, 0)
  qmatmul(s.logits, self.xq, self.xs, w.wcls, dim, c.vocab_size)
  s.logits
}
