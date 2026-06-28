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

// SIMD Adler-32 (RFC 1950). The two running sums update, per 16-byte chunk,
// as `s2 += 16*s1 + sum_j (16-j)*b[j]` and `s1 += sum_j b[j]`. The byte sum
// uses `extadd_pairwise` widening adds and the position-weighted sum uses
// `i32x4_dot_i16x8_s` (madd). Sums are reduced mod 65521 every 5552 bytes
// (zlib's NMAX), which keeps the 32-bit accumulators from overflowing.

///|
const BASE : UInt = 65521

///|
const NMAX : Int = 5552

///|
/// Weights `16-j` for the low 8 bytes of a chunk.
let weights_lo : V128 = @v128.i16x8_const(16, 15, 14, 13, 12, 11, 10, 9)

///|
/// Weights `16-j` for the high 8 bytes of a chunk.
let weights_hi : V128 = @v128.i16x8_const(8, 7, 6, 5, 4, 3, 2, 1)

///|
fn sum4(v : V128) -> UInt {
  @v128.i32x4_extract_lane(v, 0) +
  @v128.i32x4_extract_lane(v, 1) +
  @v128.i32x4_extract_lane(v, 2) +
  @v128.i32x4_extract_lane(v, 3)
}

///|
/// Computes the Adler-32 checksum of `data`.
pub fn checksum(data : FixedArray[Byte]) -> UInt {
  let len = data.length()
  let mut s1 = 1U
  let mut s2 = 0U
  let mut i = 0
  while i < len {
    let block_end = if i + NMAX < len { i + NMAX } else { len }
    while i + 16 <= block_end {
      let c = @v128.v128_load(data, i)
      // sum of the 16 bytes, via two pairwise widening adds
      let byte_sum = sum4(
        @v128.i32x4_extadd_pairwise_i16x8_u(
          @v128.i16x8_extadd_pairwise_i8x16_u(c),
        ),
      )
      // sum_j (16-j) * b[j], split into the low and high halves
      let weighted = sum4(
          @v128.i32x4_dot_i16x8_s(@v128.i16x8_extend_low_i8x16_u(c), weights_lo),
        ) +
        sum4(
          @v128.i32x4_dot_i16x8_s(
            @v128.i16x8_extend_high_i8x16_u(c),
            weights_hi,
          ),
        )
      s2 = s2 + 16U * s1 + weighted
      s1 = s1 + byte_sum
      i = i + 16
    }
    while i < block_end {
      s1 = s1 + data[i].to_uint()
      s2 = s2 + s1
      i = i + 1
    }
    s1 = s1 % BASE
    s2 = s2 % BASE
  }
  (s2 << 16) | s1
}
