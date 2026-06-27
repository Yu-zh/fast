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

// SIMD decimal integer parsing. Validation scans 16 bytes per step; the
// conversion folds eight digits at a time into a single 32-bit value using
// the multiply-add chain of Lemire ("Quickly parsing eight digits"), then
// combines eight-digit groups with 64-bit arithmetic and overflow checks.

///|
let u64_max : UInt64 = 0xffffffffffffffff

///|
/// `dot` weights that fold two two-digit values per 32-bit lane into a
/// four-digit value: `(hi*10 + ...)*100 + lo`.
let madd_100 : V128 = @v128.i16x8_const(100, 1, 100, 1, 100, 1, 100, 1)

///|
/// `dot` weights that fold the two four-digit halves into one eight-digit
/// value: `high*10000 + low`.
let madd_10000 : V128 = @v128.i16x8_const(
  10000, 1, 10000, 1, 10000, 1, 10000, 1,
)

///|
/// Parses exactly eight ASCII digits starting at `pos` into their numeric
/// value (0..99_999_999). The eight bytes must all be digits.
fn parse_8_digits(bytes : FixedArray[Byte], pos : Int) -> UInt {
  let digits = @v128.i8x16_sub(
    @v128.v128_load64_zero(bytes, pos),
    @v128.i8x16_splat(b'0'),
  )
  // fold pairs: each 16-bit lane becomes d_even*10 + d_odd
  let t1 = @v128.i16x8_add(
    @v128.i16x8_mul(
      @v128.v128_and_(digits, @v128.i16x8_splat(0x00ff)),
      @v128.i16x8_splat(10),
    ),
    @v128.i16x8_shr_u(digits, 8),
  )
  // fold quads: each 32-bit lane becomes the value of four digits
  let t2 = @v128.i32x4_dot_i16x8_s(t1, madd_100)
  // pack the two four-digit halves into adjacent 16-bit lanes
  let t3 = @v128.i16x8_narrow_i32x4_u(t2, t2)
  // combine the halves: high * 10000 + low
  let t4 = @v128.i32x4_dot_i16x8_s(t3, madd_10000)
  @v128.i32x4_extract_lane(t4, 0)
}

///|
/// Returns the index of the first byte in `[start, end)` that is not an ASCII
/// digit, or `end` if every byte is a digit.
fn first_non_digit(bytes : FixedArray[Byte], start : Int, end : Int) -> Int {
  let mut i = start
  let zero = @v128.i8x16_splat(b'0')
  let nine = @v128.i8x16_splat(b'9')
  while i + 16 <= end {
    let v = @v128.v128_load(bytes, i)
    let is_digit = @v128.v128_and_(
      @v128.i8x16_ge_u(v, zero),
      @v128.i8x16_le_u(v, nine),
    )
    let mask = @v128.i8x16_bitmask(is_digit)
    if mask != 0xffff {
      return i + (mask ^ 0xffff).ctz()
    }
    i = i + 16
  }
  while i < end {
    if bytes[i] < b'0' || bytes[i] > b'9' {
      return i
    }
    i = i + 1
  }
  end
}

///|
/// Converts the digits in `[start, end)` (already known to be all digits) to
/// an unsigned value, returning `None` on overflow of `UInt64`.
fn parse_digits(bytes : FixedArray[Byte], start : Int, end : Int) -> UInt64? {
  let ndigits = end - start
  if ndigits == 0 || ndigits > 20 {
    return None
  }
  let mut acc = 0UL
  let mut i = start
  // a short scalar prefix leaves a whole number of eight-digit blocks
  let rem = ndigits % 8
  for _ in 0..<rem {
    acc = acc * 10UL + (bytes[i] - b'0').to_uint64()
    i = i + 1
  }
  while i < end {
    let chunk = parse_8_digits(bytes, i).to_uint64()
    if acc > u64_max / 100000000UL {
      return None
    }
    acc = acc * 100000000UL
    if acc > u64_max - chunk {
      return None
    }
    acc = acc + chunk
    i = i + 8
  }
  Some(acc)
}

///|
/// Parses an unsigned decimal integer spanning the whole array. Leading zeros
/// are allowed. Returns `None` on an empty array, any non-digit byte, or a
/// value exceeding `UInt64`.
pub fn parse_uint64(bytes : FixedArray[Byte]) -> UInt64? {
  let len = bytes.length()
  if len == 0 || first_non_digit(bytes, 0, len) != len {
    return None
  }
  parse_digits(bytes, 0, len)
}

///|
/// Parses a signed decimal integer spanning the whole array, with an optional
/// leading `+` or `-`. Returns `None` on an empty array, a sign with no
/// digits, any non-digit byte, or a value outside `Int64`.
pub fn parse_int64(bytes : FixedArray[Byte]) -> Int64? {
  let len = bytes.length()
  if len == 0 {
    return None
  }
  let mut start = 0
  let mut negative = false
  if bytes[0] == b'+' {
    start = 1
  } else if bytes[0] == b'-' {
    negative = true
    start = 1
  }
  if start >= len || first_non_digit(bytes, start, len) != len {
    return None
  }
  guard parse_digits(bytes, start, len) is Some(mag) else { return None }
  if negative {
    if mag > 0x8000000000000000UL {
      return None
    }
    if mag == 0x8000000000000000UL {
      return Some(0x8000000000000000UL.reinterpret_as_int64())
    }
    Some(-mag.reinterpret_as_int64())
  } else {
    if mag > 0x7fffffffffffffffUL {
      return None
    }
    Some(mag.reinterpret_as_int64())
  }
}
