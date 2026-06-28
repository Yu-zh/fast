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

// Vector similarity search — the distance kernels under semantic search / RAG.
// Float metrics work over `FixedArray[Float]` (f32, 4 lanes per vector op);
// binary vectors use `FixedArray[Byte]` with Hamming distance via `v128_xor` +
// `i8x16_popcnt`. `top_k_cosine` is a brute-force nearest-neighbour scan that
// keeps the best k as it goes. Floating-point results are lane-partitioned, so
// they may differ from a strict sequential evaluation by rounding.

///|
fn load4(a : FixedArray[Float], i : Int) -> V128 {
  @v128.f32x4_const(a[i], a[i + 1], a[i + 2], a[i + 3])
}

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
fn minimum(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Inner product of `a` and `b` over their common prefix.
pub fn dot(a : FixedArray[Float], b : FixedArray[Float]) -> Float {
  let n = minimum(a.length(), b.length())
  let mut acc = @v128.f32x4_splat(0.0)
  let mut i = 0
  while i + 4 <= n {
    acc = @v128.f32x4_add(acc, @v128.f32x4_mul(load4(a, i), load4(b, i)))
    i = i + 4
  }
  let mut total = hsum(acc)
  while i < n {
    total = total + a[i] * b[i]
    i = i + 1
  }
  total
}

///|
/// Squared Euclidean (L2) distance between `a` and `b`.
pub fn l2_squared(a : FixedArray[Float], b : FixedArray[Float]) -> Float {
  let n = minimum(a.length(), b.length())
  let mut acc = @v128.f32x4_splat(0.0)
  let mut i = 0
  while i + 4 <= n {
    let d = @v128.f32x4_sub(load4(a, i), load4(b, i))
    acc = @v128.f32x4_add(acc, @v128.f32x4_mul(d, d))
    i = i + 4
  }
  let mut total = hsum(acc)
  while i < n {
    let d = a[i] - b[i]
    total = total + d * d
    i = i + 1
  }
  total
}

///|
/// Cosine similarity of `a` and `b` in [-1, 1]; returns 0 if either vector has
/// zero magnitude.
pub fn cosine(a : FixedArray[Float], b : FixedArray[Float]) -> Float {
  let na = fsqrt(dot(a, a))
  let nb = fsqrt(dot(b, b))
  if na == (0.0 : Float) || nb == (0.0 : Float) {
    (0.0 : Float)
  } else {
    dot(a, b) / (na * nb)
  }
}

///|
/// Hamming distance (number of differing bits) between two equal-length bit
/// vectors packed as bytes.
pub fn hamming(a : FixedArray[Byte], b : FixedArray[Byte]) -> Int {
  let n = minimum(a.length(), b.length())
  let mut i = 0
  let mut count = 0
  while i + 16 <= n {
    let x = @v128.v128_xor(@v128.v128_load(a, i), @v128.v128_load(b, i))
    let pc = @v128.i8x16_popcnt(x)
    // sum the 16 per-byte popcounts via widening pairwise adds
    let s = @v128.i32x4_extadd_pairwise_i16x8_u(
      @v128.i16x8_extadd_pairwise_i8x16_u(pc),
    )
    count = count +
      (@v128.i32x4_extract_lane(s, 0) +
      @v128.i32x4_extract_lane(s, 1) +
      @v128.i32x4_extract_lane(s, 2) +
      @v128.i32x4_extract_lane(s, 3)).reinterpret_as_int()
    i = i + 16
  }
  while i < n {
    count = count + (a[i] ^ b[i]).to_int().popcnt()
    i = i + 1
  }
  count
}

///|
/// Returns the indices and cosine scores of the `k` corpus vectors most
/// similar to `query`, in descending score order. Ties keep the earlier
/// index; fewer than `k` results are returned if the corpus is smaller.
pub fn top_k_cosine(
  query : FixedArray[Float],
  corpus : Array[FixedArray[Float]],
  k : Int,
) -> Array[(Int, Float)] {
  if k <= 0 {
    return []
  }
  let best_idx : Array[Int] = Array::make(k, -1)
  let best_score : Array[Float] = Array::make(k, -3.0e38)
  let qn = fsqrt(dot(query, query))
  for c in 0..<corpus.length() {
    let v = corpus[c]
    let vn = fsqrt(dot(v, v))
    let score = if qn == (0.0 : Float) || vn == (0.0 : Float) {
      (0.0 : Float)
    } else {
      dot(query, v) / (qn * vn)
    }
    if score > best_score[k - 1] {
      // insertion into the descending top-k buffer
      let mut p = k - 1
      while p > 0 && best_score[p - 1] < score {
        best_score[p] = best_score[p - 1]
        best_idx[p] = best_idx[p - 1]
        p = p - 1
      }
      best_score[p] = score
      best_idx[p] = c
    }
  }
  let out : Array[(Int, Float)] = []
  for i in 0..<k {
    if best_idx[i] >= 0 {
      out.push((best_idx[i], best_score[i]))
    }
  }
  out
}
