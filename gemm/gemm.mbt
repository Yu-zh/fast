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

// INT8 matrix multiply — the kernel under quantized neural-network inference —
// plus a couple of layer ops to compose a forward pass. The inner product over
// the contraction dimension widens int8 lanes to int16 (signed) and reduces
// with `i32x4_dot_i16x8_s` (madd), accumulating in int32. `B` is supplied
// transposed (`n x k`, row-major) so each output reads two contiguous rows.
// (WASM relaxed SIMD also offers a direct int8 dot-accumulate; the widen+dot
// path here is exact and portable.)

///|
fn signed8(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 128 {
    v - 256
  } else {
    v
  }
}

///|
/// Signed int8 dot product of `a[aoff..aoff+k]` and `b[boff..boff+k]`.
fn dot_i8(
  a : FixedArray[Byte],
  aoff : Int,
  b : FixedArray[Byte],
  boff : Int,
  k : Int,
) -> Int {
  let mut acc = @v128.i32x4_splat(0)
  let mut t = 0
  while t + 16 <= k {
    let va = @v128.v128_load(a, aoff + t)
    let vb = @v128.v128_load(b, boff + t)
    let lo = @v128.i32x4_dot_i16x8_s(
      @v128.i16x8_extend_low_i8x16_s(va),
      @v128.i16x8_extend_low_i8x16_s(vb),
    )
    let hi = @v128.i32x4_dot_i16x8_s(
      @v128.i16x8_extend_high_i8x16_s(va),
      @v128.i16x8_extend_high_i8x16_s(vb),
    )
    acc = @v128.i32x4_add(acc, @v128.i32x4_add(lo, hi))
    t = t + 16
  }
  let mut sum = (@v128.i32x4_extract_lane(acc, 0) +
  @v128.i32x4_extract_lane(acc, 1) +
  @v128.i32x4_extract_lane(acc, 2) +
  @v128.i32x4_extract_lane(acc, 3)).reinterpret_as_int()
  while t < k {
    sum = sum + signed8(a[aoff + t]) * signed8(b[boff + t])
    t = t + 1
  }
  sum
}

///|
/// Multiplies the `m x k` int8 matrix `a` (row-major) by the `k x n` matrix
/// whose transpose `bt` (`n x k`, row-major) is supplied, producing an
/// `m x n` int32 result in row-major order. Bytes are interpreted as signed
/// int8; results accumulate in int32.
pub fn gemm_i8(
  a : FixedArray[Byte],
  bt : FixedArray[Byte],
  m : Int,
  k : Int,
  n : Int,
) -> FixedArray[Int] {
  let c : FixedArray[Int] = FixedArray::make(m * n, 0)
  for i in 0..<m {
    let aoff = i * k
    for j in 0..<n {
      c[i * n + j] = dot_i8(a, aoff, bt, j * k, k)
    }
  }
  c
}

///|
/// Applies ReLU (`max(x, 0)`) to every element in place.
pub fn relu_i32(x : FixedArray[Int]) -> Unit {
  let len = x.length()
  let zero = @v128.i32x4_splat(0)
  let mut i = 0
  while i + 4 <= len {
    let v = @v128.i32x4_const(
      x[i].reinterpret_as_uint(),
      x[i + 1].reinterpret_as_uint(),
      x[i + 2].reinterpret_as_uint(),
      x[i + 3].reinterpret_as_uint(),
    )
    let r = @v128.i32x4_max_s(v, zero)
    x[i] = @v128.i32x4_extract_lane(r, 0).reinterpret_as_int()
    x[i + 1] = @v128.i32x4_extract_lane(r, 1).reinterpret_as_int()
    x[i + 2] = @v128.i32x4_extract_lane(r, 2).reinterpret_as_int()
    x[i + 3] = @v128.i32x4_extract_lane(r, 3).reinterpret_as_int()
    i = i + 4
  }
  while i < len {
    if x[i] < 0 {
      x[i] = 0
    }
    i = i + 1
  }
}

///|
/// Returns the index of the first maximum element (e.g. the predicted class
/// of a logit vector), or `None` if empty.
pub fn argmax_i32(x : FixedArray[Int]) -> Int? {
  let len = x.length()
  if len == 0 {
    return None
  }
  let mut acc = @v128.i32x4_splat(x[0].reinterpret_as_uint())
  let mut i = 0
  while i + 4 <= len {
    let v = @v128.i32x4_const(
      x[i].reinterpret_as_uint(),
      x[i + 1].reinterpret_as_uint(),
      x[i + 2].reinterpret_as_uint(),
      x[i + 3].reinterpret_as_uint(),
    )
    acc = @v128.i32x4_max_s(acc, v)
    i = i + 4
  }
  let mut best = @v128.i32x4_extract_lane(acc, 0).reinterpret_as_int()
  for lane in 1..<4 {
    let v = @v128.i32x4_extract_lane(acc, lane).reinterpret_as_int()
    if v > best {
      best = v
    }
  }
  while i < len {
    if x[i] > best {
      best = x[i]
    }
    i = i + 1
  }
  for j in 0..<len {
    if x[j] == best {
      return Some(j)
    }
  }
  None
}
