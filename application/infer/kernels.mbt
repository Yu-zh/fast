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

// The neural-network kernels of a Llama-style transformer, over f32
// (`FixedArray[Float]`). `matmul` (the hot path) and `rmsnorm` use `f32x4`
// SIMD; `softmax` and `silu` are SIMD where they can be, with the
// transcendental `exp` applied per element; `rope` (rotary position encoding)
// is pairwise scalar. These compose into the forward pass in `model.mbt`.

///|
fn hsum(v : V128) -> Float {
  @v128.f32x4_extract_lane(v, 0) +
  @v128.f32x4_extract_lane(v, 1) +
  @v128.f32x4_extract_lane(v, 2) +
  @v128.f32x4_extract_lane(v, 3)
}

///|
fn fsqrt(x : Float) -> Float {
  @v128.f32x4_extract_lane(@v128.f32x4_sqrt(@v128.f32x4_splat(x)), 0)
}

///|
fn expf(x : Float) -> Float {
  Float::from_double(@math.exp(x.to_double()))
}

///|
/// Dot product of `a[aoff..aoff+n]` and `b[boff..boff+n]` (f32x4).
fn dot(
  a : FixedArray[Float],
  aoff : Int,
  b : FixedArray[Float],
  boff : Int,
  n : Int,
) -> Float {
  let mut acc = @v128.f32x4_splat(0.0)
  let mut j = 0
  while j + 4 <= n {
    let av = @v128.f32x4_const(
      a[aoff + j],
      a[aoff + j + 1],
      a[aoff + j + 2],
      a[aoff + j + 3],
    )
    let bv = @v128.f32x4_const(
      b[boff + j],
      b[boff + j + 1],
      b[boff + j + 2],
      b[boff + j + 3],
    )
    acc = @v128.f32x4_add(acc, @v128.f32x4_mul(av, bv))
    j = j + 4
  }
  let mut s = hsum(acc)
  while j < n {
    s = s + a[aoff + j] * b[boff + j]
    j = j + 1
  }
  s
}

///|
/// Matrix-vector product: `out = W @ x` where `W` is `d` rows of length `n`
/// (row-major) and `x` has length `n`. `out` must have length `d`. This is the
/// dominant cost of transformer inference.
pub fn matmul(
  out : FixedArray[Float],
  x : FixedArray[Float],
  w : FixedArray[Float],
  n : Int,
  d : Int,
) -> Unit {
  for i in 0..<d {
    out[i] = dot(w, i * n, x, 0, n)
  }
}

///|
/// RMSNorm: `out[j] = x[j] * weight[j] / sqrt(mean(x^2) + eps)`, the
/// normalization Llama uses in place of LayerNorm.
pub fn rmsnorm(
  out : FixedArray[Float],
  x : FixedArray[Float],
  weight : FixedArray[Float],
  size : Int,
) -> Unit {
  // sum of squares (SIMD)
  let mut acc = @v128.f32x4_splat(0.0)
  let mut j = 0
  while j + 4 <= size {
    let xv = @v128.f32x4_const(x[j], x[j + 1], x[j + 2], x[j + 3])
    acc = @v128.f32x4_add(acc, @v128.f32x4_mul(xv, xv))
    j = j + 4
  }
  let mut ss = hsum(acc)
  while j < size {
    ss = ss + x[j] * x[j]
    j = j + 1
  }
  ss = ss / Float::from_int(size) + (1.0e-5 : Float)
  let scale = (1.0 : Float) / fsqrt(ss)
  let sv = @v128.f32x4_splat(scale)
  j = 0
  while j + 4 <= size {
    let xv = @v128.f32x4_const(x[j], x[j + 1], x[j + 2], x[j + 3])
    let wv = @v128.f32x4_const(
      weight[j],
      weight[j + 1],
      weight[j + 2],
      weight[j + 3],
    )
    let r = @v128.f32x4_mul(@v128.f32x4_mul(xv, sv), wv)
    out[j] = @v128.f32x4_extract_lane(r, 0)
    out[j + 1] = @v128.f32x4_extract_lane(r, 1)
    out[j + 2] = @v128.f32x4_extract_lane(r, 2)
    out[j + 3] = @v128.f32x4_extract_lane(r, 3)
    j = j + 4
  }
  while j < size {
    out[j] = x[j] * scale * weight[j]
    j = j + 1
  }
}

///|
/// Numerically-stable softmax over `x[off..off+size]`, in place.
pub fn softmax(x : FixedArray[Float], off : Int, size : Int) -> Unit {
  // max (SIMD-ish via scalar over a small range is fine; kept scalar for the
  // per-head attention case where size is the sequence position count)
  let mut max_val = x[off]
  for i in 1..<size {
    if x[off + i] > max_val {
      max_val = x[off + i]
    }
  }
  let mut sum = (0.0 : Float)
  for i in 0..<size {
    let e = expf(x[off + i] - max_val)
    x[off + i] = e
    sum = sum + e
  }
  let inv = (1.0 : Float) / sum
  for i in 0..<size {
    x[off + i] = x[off + i] * inv
  }
}

///|
/// SwiGLU activation: `gate[i] = silu(gate[i]) * up[i]` in place, where
/// `silu(v) = v / (1 + exp(-v))`.
pub fn swiglu(
  gate : FixedArray[Float],
  up : FixedArray[Float],
  size : Int,
) -> Unit {
  for i in 0..<size {
    let v = gate[i]
    let silu = v / ((1.0 : Float) + expf(-v))
    gate[i] = silu * up[i]
  }
}

///|
/// Applies rotary position embeddings (RoPE, NeoX/llama2.c style) to the query
/// vector `q` (length `dim`) and key vector `k` (length `kv_dim`) at position
/// `pos`, rotating each adjacent pair within a head.
pub fn rope(
  q : FixedArray[Float],
  k : FixedArray[Float],
  pos : Int,
  dim : Int,
  kv_dim : Int,
  head_size : Int,
) -> Unit {
  let mut i = 0
  while i < dim {
    let head_dim = i % head_size
    let freq = 1.0 /
      @math.pow(10000.0, head_dim.to_double() / head_size.to_double())
    let val = pos.to_double() * freq
    let fcr = Float::from_double(@math.cos(val))
    let fci = Float::from_double(@math.sin(val))
    // rotate q always; rotate k only while within the key dimensions
    let rotn = if i < kv_dim { 2 } else { 1 }
    for v in 0..<rotn {
      let vec = if v == 0 { q } else { k }
      let v0 = vec[i]
      let v1 = vec[i + 1]
      vec[i] = v0 * fcr - v1 * fci
      vec[i + 1] = v0 * fci + v1 * fcr
    }
    i = i + 2
  }
}
