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

// SIMD integer formatting. An eight-digit group is expanded with two
// reciprocal-multiply steps that need no `mulhi`: divide by 100 via
// `x*5243 >> 19` and by 10 via `n*103 >> 10` (both exact over their input
// ranges, and chosen so the products stay within `i32x4_mul`). The resulting
// digit lanes are interleaved with `i8x16_shuffle` and biased to ASCII. A
// 64-bit value is split into up to three such groups; leading zeros from the
// high groups are then trimmed.

///|
/// Expands `v8` (which must be < 100_000_000) into eight ASCII digit bytes,
/// most significant first, in the low 8 bytes of the result.
fn format_8_digits(v8 : UInt) -> V128 {
  let hi4 = v8 / 10000U
  let lo4 = v8 % 10000U
  let pair = @v128.i32x4_const(hi4, lo4, 0, 0)
  // /100: lanes become [hi4/100, lo4/100], i.e. the top two digits of each
  let top2 = @v128.i32x4_shr_u(
    @v128.i32x4_mul(pair, @v128.i32x4_splat(5243)),
    19,
  )
  // remainder gives the bottom two digits of each half
  let bot2 = @v128.i32x4_sub(
    pair,
    @v128.i32x4_mul(top2, @v128.i32x4_splat(100)),
  )
  // regroup into [top2.hi, bot2.hi, top2.lo, bot2.lo] so each lane is a 2-digit
  // value, in output order
  let quad = @v128.i8x16_shuffle(
    top2, bot2, 0, 1, 2, 3, 16, 17, 18, 19, 4, 5, 6, 7, 20, 21, 22, 23,
  )
  // split each 2-digit value into its tens and units digit
  let tens = @v128.i32x4_shr_u(
    @v128.i32x4_mul(quad, @v128.i32x4_splat(103)),
    10,
  )
  let units = @v128.i32x4_sub(
    quad,
    @v128.i32x4_mul(tens, @v128.i32x4_splat(10)),
  )
  // interleave tens/units (each in the low byte of its lane) into 8 digits
  let digits = @v128.i8x16_shuffle(
    tens, units, 0, 16, 4, 20, 8, 24, 12, 28, 0, 0, 0, 0, 0, 0, 0, 0,
  )
  @v128.i8x16_add(digits, @v128.i8x16_splat(b'0'))
}

///|
fn store_8(buf : FixedArray[Byte], offset : Int, v8 : UInt) -> Unit {
  @v128.v128_store64_lane(buf, offset, format_8_digits(v8), 0)
}

///|
/// Formats `value` as decimal ASCII (no leading zeros, no sign).
pub fn format_uint64(value : UInt64) -> FixedArray[Byte] {
  if value == 0UL {
    return [b'0']
  }
  // up to 20 digits = three eight-digit groups (the high group is <= 1844)
  let buf : FixedArray[Byte] = FixedArray::make(24, b'0')
  store_8(buf, 0, (value / 10000000000000000UL).to_uint())
  store_8(buf, 8, (value / 100000000UL % 100000000UL).to_uint())
  store_8(buf, 16, (value % 100000000UL).to_uint())
  let mut start = 0
  while start < 23 && buf[start] == b'0' {
    start = start + 1
  }
  let out : FixedArray[Byte] = FixedArray::make(24 - start, 0)
  for k in 0..<(24 - start) {
    out[k] = buf[start + k]
  }
  out
}

///|
/// Formats `value` as decimal ASCII, with a leading `-` when negative.
pub fn format_int64(value : Int64) -> FixedArray[Byte] {
  if value >= 0L {
    return format_uint64(value.reinterpret_as_uint64())
  }
  // two's-complement magnitude, correct even for Int64::min
  let mag = 0UL - value.reinterpret_as_uint64()
  let digits = format_uint64(mag)
  let out : FixedArray[Byte] = FixedArray::make(digits.length() + 1, b'-')
  for k in 0..<digits.length() {
    out[k + 1] = digits[k]
  }
  out
}

///|
/// Formats a 32-bit `Int` as decimal ASCII, with a leading `-` when negative.
pub fn format_int(value : Int) -> FixedArray[Byte] {
  format_int64(value.to_int64())
}
