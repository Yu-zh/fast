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

// Standard base32 (RFC 4648). Unlike base64's clean 6-bits-from-3-bytes split,
// base32's 5-bit fields straddle bytes irregularly and do not map onto v128's
// lane-uniform shifts, so the bit (un)packing is scalar. The parts that do
// vectorize cleanly use SIMD: encoding maps 5-bit indices to ASCII with two
// `i8x16_swizzle` tables (the alphabet has 32 entries, so a low/high pair),
// and decoding validates the alphabet 16 bytes at a time.

///|
let alphabet : Bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

///|
/// Alphabet entries for indices 0-15 (`A`-`P`).
let lo_table : V128 = @v128.i8x16_const(
  b'A', b'B', b'C', b'D', b'E', b'F', b'G', b'H', b'I', b'J', b'K', b'L', b'M', b'N',
  b'O', b'P',
)

///|
/// Alphabet entries for indices 16-31 (`Q`-`Z`, `2`-`7`).
let hi_table : V128 = @v128.i8x16_const(
  b'Q', b'R', b'S', b'T', b'U', b'V', b'W', b'X', b'Y', b'Z', b'2', b'3', b'4', b'5',
  b'6', b'7',
)

///|
/// SIMD-maps the `count` 5-bit indices in `idx` (values 0-31) to alphabet
/// characters in `out`.
fn map_indices(
  idx : FixedArray[Byte],
  out : FixedArray[Byte],
  count : Int,
) -> Unit {
  let sixteen = @v128.i8x16_splat(16)
  let mut i = 0
  while i + 16 <= count {
    let v = @v128.v128_load(idx, i)
    // indices < 16 look up lo_table (others swizzle to 0); >= 16 use hi_table
    let clo = @v128.i8x16_swizzle(lo_table, v)
    let chi = @v128.i8x16_swizzle(hi_table, @v128.i8x16_sub(v, sixteen))
    @v128.v128_store(out, i, @v128.v128_or_(clo, chi))
    i = i + 16
  }
  while i < count {
    out[i] = alphabet[idx[i].to_int()]
    i = i + 1
  }
}

///|
/// Encodes `bytes` as standard, padded base32.
pub fn encode(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let n = bytes.length()
  let out_len = (n + 4) / 5 * 8
  let out : FixedArray[Byte] = FixedArray::make(out_len, b'=')
  let data_chars = (n * 8 + 4) / 5
  let idx : FixedArray[Byte] = FixedArray::make(data_chars, 0)
  // scalar bit extraction: pull 5-bit groups out of the byte stream
  let mut bitbuf = 0
  let mut bits = 0
  let mut pos = 0
  for i in 0..<n {
    bitbuf = (bitbuf << 8) | bytes[i].to_int()
    bits = bits + 8
    while bits >= 5 {
      bits = bits - 5
      idx[pos] = ((bitbuf >> bits) & 0x1f).to_byte()
      pos = pos + 1
    }
    bitbuf = bitbuf & ((1 << bits) - 1)
  }
  if bits > 0 {
    idx[pos] = ((bitbuf << (5 - bits)) & 0x1f).to_byte()
  }
  map_indices(idx, out, data_chars)
  out
}

///|
fn decode_value(b : Byte) -> Int {
  if b >= b'A' && b <= b'Z' {
    (b - b'A').to_int()
  } else if b >= b'2' && b <= b'7' {
    (b - b'2').to_int() + 26
  } else {
    -1
  }
}

///|
/// Returns the index of the first character in `[0, sig)` outside the base32
/// alphabet, or -1 if all are valid.
fn find_invalid(input : FixedArray[Byte], sig : Int) -> Int {
  let a = @v128.i8x16_splat(b'A')
  let z = @v128.i8x16_splat(b'Z')
  let two = @v128.i8x16_splat(b'2')
  let seven = @v128.i8x16_splat(b'7')
  let mut i = 0
  while i + 16 <= sig {
    let v = @v128.v128_load(input, i)
    let valid = @v128.v128_or_(
      @v128.v128_and_(@v128.i8x16_ge_u(v, a), @v128.i8x16_le_u(v, z)),
      @v128.v128_and_(@v128.i8x16_ge_u(v, two), @v128.i8x16_le_u(v, seven)),
    )
    let mask = @v128.i8x16_bitmask(valid)
    if mask != 0xffff {
      return i + (mask ^ 0xffff).ctz()
    }
    i = i + 16
  }
  while i < sig {
    if decode_value(input[i]) < 0 {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Decodes standard base32 (uppercase, with or without `=` padding). Returns
/// `None` on any character outside the alphabet, misplaced padding, or an
/// invalid length.
pub fn decode(input : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = input.length()
  let mut sig = len
  while sig > 0 && input[sig - 1] == b'=' {
    sig = sig - 1
  }
  // valid remainders for a base32 group are 0, 2, 4, 5, 7 characters
  let rem = sig % 8
  if rem == 1 || rem == 3 || rem == 6 {
    return None
  }
  if find_invalid(input, sig) >= 0 {
    return None
  }
  let out_len = sig * 5 / 8
  let out : FixedArray[Byte] = FixedArray::make(out_len, 0)
  let mut bitbuf = 0
  let mut bits = 0
  let mut o = 0
  for i in 0..<sig {
    bitbuf = (bitbuf << 5) | decode_value(input[i])
    bits = bits + 5
    if bits >= 8 {
      bits = bits - 8
      out[o] = ((bitbuf >> bits) & 0xff).to_byte()
      o = o + 1
      bitbuf = bitbuf & ((1 << bits) - 1)
    }
  }
  Some(out)
}
