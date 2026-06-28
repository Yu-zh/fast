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

// SIMD inclusive prefix sum (scan) over `FixedArray[Int]`. Each block of four
// lanes is scanned with a two-step Hillis-Steele pass — add the vector shifted
// right by one lane, then by two — implemented with `i8x16_shuffle` against a
// zero vector. A scalar carry threads the running total between blocks. Sums
// wrap on 32-bit overflow, matching a scalar `+` accumulation.

///|
/// `[a, b, c, d]` -> `[0, a, b, c]` (shift lanes right by one, zero fill).
fn shift1(x : V128, zeros : V128) -> V128 {
  @v128.i8x16_shuffle(
    x, zeros, 16, 17, 18, 19, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  )
}

///|
/// `[a, b, c, d]` -> `[0, 0, a, b]` (shift lanes right by two, zero fill).
fn shift2(x : V128, zeros : V128) -> V128 {
  @v128.i8x16_shuffle(
    x, zeros, 16, 17, 18, 19, 16, 17, 18, 19, 0, 1, 2, 3, 4, 5, 6, 7,
  )
}

///|
/// Returns the inclusive prefix sums of `values`: `out[i] = values[0] + ... +
/// values[i]`. Addition wraps on 32-bit overflow.
pub fn scan_int(values : FixedArray[Int]) -> FixedArray[Int] {
  let n = values.length()
  let out : FixedArray[Int] = FixedArray::make(n, 0)
  let zeros = @v128.i32x4_splat(0)
  let mut carry = 0
  let mut i = 0
  while i + 4 <= n {
    let x = @v128.i32x4_const(
      values[i].reinterpret_as_uint(),
      values[i + 1].reinterpret_as_uint(),
      values[i + 2].reinterpret_as_uint(),
      values[i + 3].reinterpret_as_uint(),
    )
    let s1 = @v128.i32x4_add(x, shift1(x, zeros))
    let s2 = @v128.i32x4_add(s1, shift2(s1, zeros))
    let r = @v128.i32x4_add(s2, @v128.i32x4_splat(carry.reinterpret_as_uint()))
    out[i] = @v128.i32x4_extract_lane(r, 0).reinterpret_as_int()
    out[i + 1] = @v128.i32x4_extract_lane(r, 1).reinterpret_as_int()
    out[i + 2] = @v128.i32x4_extract_lane(r, 2).reinterpret_as_int()
    out[i + 3] = @v128.i32x4_extract_lane(r, 3).reinterpret_as_int()
    carry = out[i + 3]
    i = i + 4
  }
  while i < n {
    carry = carry + values[i]
    out[i] = carry
    i = i + 1
  }
  out
}
