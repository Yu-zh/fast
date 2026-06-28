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

// Reads the llama2.c "legacy" checkpoint format: a 7 x int32 header
// (dim, hidden_dim, n_layers, n_heads, n_kv_heads, vocab_size, seq_len; a
// negative vocab_size flags an unshared classifier) followed by all weights as
// little-endian float32 in a fixed order. The per-layer matrices are sliced
// into one `FixedArray[Float]` per layer so they feed `matmul` directly.

///|
fn u32le(d : Bytes, o : Int) -> UInt {
  d[o].to_uint() |
  (d[o + 1].to_uint() << 8) |
  (d[o + 2].to_uint() << 16) |
  (d[o + 3].to_uint() << 24)
}

///|
fn i32le(d : Bytes, o : Int) -> Int {
  u32le(d, o).reinterpret_as_int()
}

///|
fn f32le(d : Bytes, o : Int) -> Float {
  Float::reinterpret_from_uint(u32le(d, o))
}

///|
/// A forward cursor over the float section of a checkpoint.
priv struct Cursor {
  data : Bytes
  mut off : Int
}

///|
fn Cursor::floats(self : Cursor, count : Int) -> FixedArray[Float] {
  let a : FixedArray[Float] = FixedArray::make(count, 0.0)
  for i in 0..<count {
    a[i] = f32le(self.data, self.off + i * 4)
  }
  self.off = self.off + count * 4
  a
}

///|
fn Cursor::layers(
  self : Cursor,
  n_layers : Int,
  per : Int,
) -> Array[FixedArray[Float]] {
  let out : Array[FixedArray[Float]] = []
  for _ in 0..<n_layers {
    out.push(self.floats(per))
  }
  out
}

///|
fn Cursor::skip(self : Cursor, count : Int) -> Unit {
  self.off = self.off + count * 4
}

///|
/// Parses a llama2.c checkpoint from its raw bytes into a `Config` and
/// `Weights`.
pub fn load_checkpoint(data : Bytes) -> (Config, Weights) {
  let dim = i32le(data, 0)
  let hidden_dim = i32le(data, 4)
  let n_layers = i32le(data, 8)
  let n_heads = i32le(data, 12)
  let n_kv_heads = i32le(data, 16)
  let vocab_raw = i32le(data, 20)
  let seq_len = i32le(data, 24)
  let shared = vocab_raw > 0
  let vocab = if vocab_raw < 0 { -vocab_raw } else { vocab_raw }
  let config = Config::{
    dim,
    hidden_dim,
    n_layers,
    n_heads,
    n_kv_heads,
    vocab_size: vocab,
    seq_len,
  }
  let head_size = dim / n_heads
  let kv_dim = n_kv_heads * head_size
  let c = Cursor::{ data, off: 28 }
  let token_embedding = c.floats(vocab * dim)
  let rms_att = c.layers(n_layers, dim)
  let wq = c.layers(n_layers, dim * dim)
  let wk = c.layers(n_layers, kv_dim * dim)
  let wv = c.layers(n_layers, kv_dim * dim)
  let wo = c.layers(n_layers, dim * dim)
  let rms_ffn = c.layers(n_layers, dim)
  let w1 = c.layers(n_layers, hidden_dim * dim)
  let w2 = c.layers(n_layers, dim * hidden_dim)
  let w3 = c.layers(n_layers, hidden_dim * dim)
  let rms_final = c.floats(dim)
  // skip the precomputed RoPE tables (we recompute them in `rope`)
  c.skip(seq_len * head_size / 2)
  c.skip(seq_len * head_size / 2)
  let wcls = if shared { token_embedding } else { c.floats(vocab * dim) }
  let weights = Weights::{
    token_embedding,
    rms_att,
    wq,
    wk,
    wv,
    wo,
    rms_ffn,
    w1,
    w2,
    w3,
    rms_final,
    wcls,
  }
  (config, weights)
}
