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

// UTF-8 validation using the nibble-lookup algorithm from Keiser & Lemire,
// "Validating UTF-8 In Less Than One Instruction Per Byte" (the simdjson
// "lookup4" validator). Each pair of adjacent bytes is classified through
// three 16-entry nibble tables whose entries are error bitsets; 3- and
// 4-byte sequences are additionally checked by locating their mandatory
// continuation bytes. Any byte that sets an error bit makes the whole
// input invalid.

///|
/// Error bits. `OVERLONG_4` shares a bit with `TOO_LARGE_1000` and
/// `TWO_CONTS` is the high bit so it lines up with the continuation check.
const TOO_SHORT : Byte = 0x01

///|
const TOO_LONG : Byte = 0x02

///|
const OVERLONG_3 : Byte = 0x04

///|
const TOO_LARGE : Byte = 0x08

///|
const SURROGATE : Byte = 0x10

///|
const OVERLONG_2 : Byte = 0x20

///|
const TOO_LARGE_1000 : Byte = 0x40

///|
const OVERLONG_4 : Byte = 0x40

///|
const TWO_CONTS : Byte = 0x80

///|
const CARRY : Byte = 0x83 // TOO_SHORT | TOO_LONG | TWO_CONTS

///|
/// Classification of the high nibble of the previous byte.
let byte_1_high_table : V128 = @v128.i8x16_const(
  TOO_LONG,
  TOO_LONG,
  TOO_LONG,
  TOO_LONG,
  TOO_LONG,
  TOO_LONG,
  TOO_LONG,
  TOO_LONG,
  TWO_CONTS,
  TWO_CONTS,
  TWO_CONTS,
  TWO_CONTS,
  TOO_SHORT | OVERLONG_2,
  TOO_SHORT,
  TOO_SHORT | OVERLONG_3 | SURROGATE,
  TOO_SHORT | TOO_LARGE | TOO_LARGE_1000 | OVERLONG_4,
)

///|
/// Classification of the low nibble of the previous byte.
let byte_1_low_table : V128 = @v128.i8x16_const(
  CARRY | OVERLONG_3 | OVERLONG_2 | OVERLONG_4,
  CARRY | OVERLONG_2,
  CARRY,
  CARRY,
  CARRY | TOO_LARGE,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000 | SURROGATE,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
  CARRY | TOO_LARGE | TOO_LARGE_1000,
)

///|
/// Classification of the high nibble of the current byte.
let byte_2_high_table : V128 = @v128.i8x16_const(
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_LONG | OVERLONG_2 | TWO_CONTS | OVERLONG_3 | TOO_LARGE_1000 | OVERLONG_4,
  TOO_LONG | OVERLONG_2 | TWO_CONTS | OVERLONG_3 | TOO_LARGE,
  TOO_LONG | OVERLONG_2 | TWO_CONTS | SURROGATE | TOO_LARGE,
  TOO_LONG | OVERLONG_2 | TWO_CONTS | SURROGATE | TOO_LARGE,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
  TOO_SHORT,
)

///|
/// A block may not end with an unfinished sequence: a 2-byte lead in the
/// last position, a 3-byte lead in the last two, or a 4-byte lead in the
/// last three. Saturating subtraction leaves a nonzero lane exactly where
/// that happens.
let incomplete_check : V128 = @v128.i8x16_const(
  0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xef,
  0xdf, 0xbf,
)

///|
fn high_nibbles(v : V128) -> V128 {
  @v128.v128_and_(@v128.i16x8_shr_u(v, 4), @v128.i8x16_splat(0x0f))
}

///|
fn is_incomplete(input : V128) -> V128 {
  @v128.i8x16_sub_sat_u(input, incomplete_check)
}

///|
/// Returns a vector of error bits for one 16-byte block given the previous
/// block (for sequences that straddle the boundary).
fn check_block(input : V128, prev : V128) -> V128 {
  let prev1 = @v128.i8x16_shuffle(
    prev, input, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
  )
  let byte_1_high = @v128.i8x16_swizzle(byte_1_high_table, high_nibbles(prev1))
  let byte_1_low = @v128.i8x16_swizzle(
    byte_1_low_table,
    @v128.v128_and_(prev1, @v128.i8x16_splat(0x0f)),
  )
  let byte_2_high = @v128.i8x16_swizzle(byte_2_high_table, high_nibbles(input))
  let special_cases = @v128.v128_and_(
    @v128.v128_and_(byte_1_high, byte_1_low),
    byte_2_high,
  )
  // Bytes two and three positions back that are 3-/4-byte leads demand a
  // continuation here; TWO_CONTS (0x80) in `special_cases` reports whether
  // one is present. XOR flags both a missing and an unexpected continuation.
  let prev2 = @v128.i8x16_shuffle(
    prev, input, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
  )
  let prev3 = @v128.i8x16_shuffle(
    prev, input, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
  )
  let is_third_byte = @v128.i8x16_sub_sat_u(prev2, @v128.i8x16_splat(0x60))
  let is_fourth_byte = @v128.i8x16_sub_sat_u(prev3, @v128.i8x16_splat(0x70))
  let must23_80 = @v128.v128_and_(
    @v128.v128_or_(is_third_byte, is_fourth_byte),
    @v128.i8x16_splat(0x80),
  )
  @v128.v128_xor(must23_80, special_cases)
}

///|
/// Returns `true` when `bytes` is well-formed UTF-8 (rejecting overlong
/// encodings, surrogates, and code points above U+10FFFF).
pub fn validate(bytes : FixedArray[Byte]) -> Bool {
  let len = bytes.length()
  let zero = @v128.i64x2_splat(0)
  let mut error = zero
  let mut prev = zero
  let mut prev_incomplete = zero
  let mut i = 0
  while i + 16 <= len {
    let input = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(input) == 0 {
      // pure ASCII: only a sequence left unfinished by the previous block
      // can be wrong
      error = @v128.v128_or_(error, prev_incomplete)
      prev_incomplete = zero
    } else {
      error = @v128.v128_or_(error, check_block(input, prev))
      prev_incomplete = is_incomplete(input)
    }
    prev = input
    i = i + 16
  }
  // Process the remainder as one zero-padded block. The padding is ASCII,
  // so a sequence truncated by the true end of input fails as TOO_SHORT,
  // and an empty remainder reduces to the prev_incomplete check.
  let tail : FixedArray[Byte] = FixedArray::make(16, 0)
  for j in i..<len {
    tail[j - i] = bytes[j]
  }
  let input = @v128.v128_load(tail, 0)
  if @v128.i8x16_bitmask(input) == 0 {
    error = @v128.v128_or_(error, prev_incomplete)
  } else {
    error = @v128.v128_or_(error, check_block(input, prev))
  }
  !@v128.v128_any_true(error)
}
