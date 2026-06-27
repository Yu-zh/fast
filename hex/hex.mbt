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

///|
let hex_digits : V128 = @v128.i8x16_const(
  b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9', b'a', b'b', b'c', b'd',
  b'e', b'f',
)

///|
fn high_nibbles(v : V128) -> V128 {
  @v128.v128_and_(@v128.i16x8_shr_u(v, 4), @v128.i8x16_splat(0x0f))
}

///|
/// Encodes `bytes` as lowercase hex, two output bytes per input byte.
pub fn encode(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let out : FixedArray[Byte] = FixedArray::make(len * 2, 0)
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let hi = @v128.i8x16_swizzle(hex_digits, high_nibbles(v))
    let lo = @v128.i8x16_swizzle(
      hex_digits,
      @v128.v128_and_(v, @v128.i8x16_splat(0x0f)),
    )
    // interleave: high digit then low digit for each input byte
    @v128.v128_store(
      out,
      i * 2,
      @v128.i8x16_shuffle(
        hi, lo, 0, 16, 1, 17, 2, 18, 3, 19, 4, 20, 5, 21, 6, 22, 7, 23,
      ),
    )
    @v128.v128_store(
      out,
      i * 2 + 16,
      @v128.i8x16_shuffle(
        hi, lo, 8, 24, 9, 25, 10, 26, 11, 27, 12, 28, 13, 29, 14, 30, 15, 31,
      ),
    )
    i = i + 16
  }
  while i < len {
    let b = bytes[i]
    out[i * 2] = encode_nibble(b.to_int() >> 4)
    out[i * 2 + 1] = encode_nibble(b.to_int() & 0x0f)
    i = i + 1
  }
  out
}

///|
fn encode_nibble(n : Int) -> Byte {
  if n < 10 {
    b'0' + n.to_byte()
  } else {
    b'a' + (n - 10).to_byte()
  }
}

///|
fn decode_nibble(b : Byte) -> Int {
  if b >= b'0' && b <= b'9' {
    (b - b'0').to_int()
  } else {
    let folded = b | 0x20
    if folded >= b'a' && folded <= b'f' {
      (folded - b'a').to_int() + 10
    } else {
      -1
    }
  }
}

///|
/// Decodes a hex string (either case). Returns `None` when the length is
/// odd or any byte is not a hex digit.
pub fn decode(hex : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = hex.length()
  if len % 2 != 0 {
    return None
  }
  let out : FixedArray[Byte] = FixedArray::make(len / 2, 0)
  let zero = @v128.i8x16_splat(b'0')
  let nine = @v128.i8x16_splat(b'9')
  let la = @v128.i8x16_splat(b'a')
  let lf = @v128.i8x16_splat(b'f')
  let case_bit = @v128.i8x16_splat(0x20)
  let alpha_base = @v128.i8x16_splat(b'a' - 10)
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(hex, i)
    // fold case, then classify with two range checks; '0'-'9' uses v - '0'
    // and 'a'-'f'/'A'-'F' use folded - ('a' - 10)
    let folded = @v128.v128_or_(v, case_bit)
    let is_digit = @v128.v128_and_(
      @v128.i8x16_ge_u(v, zero),
      @v128.i8x16_le_u(v, nine),
    )
    let is_alpha = @v128.v128_and_(
      @v128.i8x16_ge_u(folded, la),
      @v128.i8x16_le_u(folded, lf),
    )
    if @v128.i8x16_bitmask(@v128.v128_or_(is_digit, is_alpha)) != 0xffff {
      return None
    }
    let nibbles = @v128.v128_bitselect(
      @v128.i8x16_sub(v, zero),
      @v128.i8x16_sub(folded, alpha_base),
      is_digit,
    )
    // each u16 lane holds [high nibble char | low nibble char << 8];
    // combine into the result byte in the lane's low half
    let combined = @v128.v128_or_(
      @v128.i16x8_shl(@v128.v128_and_(nibbles, @v128.i16x8_splat(0x00ff)), 4),
      @v128.i16x8_shr_u(nibbles, 8),
    )
    let packed = @v128.i8x16_swizzle(
      combined,
      @v128.i8x16_const(
        0, 2, 4, 6, 8, 10, 12, 14, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      ),
    )
    @v128.v128_store64_lane(out, i / 2, packed, 0)
    i = i + 16
  }
  while i < len {
    let hi = decode_nibble(hex[i])
    let lo = decode_nibble(hex[i + 1])
    if hi < 0 || lo < 0 {
      return None
    }
    out[i / 2] = ((hi << 4) | lo).to_byte()
    i = i + 2
  }
  Some(out)
}
