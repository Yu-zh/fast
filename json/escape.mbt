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

// JSON string escaping (the serialization side). A SIMD scan finds the bytes
// that need escaping (`"`, `\`, and control characters below 0x20); chunks
// with none are copied verbatim. The output length is computed exactly in a
// first pass so the result buffer is sized precisely.

///|
fn escape_cost(b : Byte) -> Int {
  if b == b'"' ||
    b == b'\\' ||
    b == 0x08 ||
    b == 0x09 ||
    b == 0x0a ||
    b == 0x0c ||
    b == 0x0d {
    2
  } else if b < 0x20 {
    6
  } else {
    1
  }
}

///|
fn hex_digit(n : Int) -> Byte {
  if n < 10 {
    b'0' + n.to_byte()
  } else {
    b'a' + (n - 10).to_byte()
  }
}

///|
/// Writes the escaped form of `b` at `pos` in `out`, returning the next
/// position.
fn write_escaped(out : FixedArray[Byte], pos : Int, b : Byte) -> Int {
  if b == b'"' {
    out[pos] = b'\\'
    out[pos + 1] = b'"'
    pos + 2
  } else if b == b'\\' {
    out[pos] = b'\\'
    out[pos + 1] = b'\\'
    pos + 2
  } else if b == 0x08 {
    out[pos] = b'\\'
    out[pos + 1] = b'b'
    pos + 2
  } else if b == 0x09 {
    out[pos] = b'\\'
    out[pos + 1] = b't'
    pos + 2
  } else if b == 0x0a {
    out[pos] = b'\\'
    out[pos + 1] = b'n'
    pos + 2
  } else if b == 0x0c {
    out[pos] = b'\\'
    out[pos + 1] = b'f'
    pos + 2
  } else if b == 0x0d {
    out[pos] = b'\\'
    out[pos + 1] = b'r'
    pos + 2
  } else if b < 0x20 {
    out[pos] = b'\\'
    out[pos + 1] = b'u'
    out[pos + 2] = b'0'
    out[pos + 3] = b'0'
    out[pos + 4] = hex_digit(b.to_int() >> 4)
    out[pos + 5] = hex_digit(b.to_int() & 0x0f)
    pos + 6
  } else {
    out[pos] = b
    pos + 1
  }
}

///|
/// Returns the JSON-escaped form of `bytes` (the contents that go *between*
/// the surrounding quotes), with `"`, `\`, and control characters escaped.
/// Bytes >= 0x20 other than `"` and `\` — including multi-byte UTF-8 — are
/// passed through unchanged.
pub fn escape_string(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let quote = @v128.i8x16_splat(b'"')
  let backslash = @v128.i8x16_splat(b'\\')
  let space = @v128.i8x16_splat(0x20)
  // pass 1: exact output length
  let mut total = 0
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let special = @v128.v128_or_(
      @v128.v128_or_(@v128.i8x16_eq(v, quote), @v128.i8x16_eq(v, backslash)),
      @v128.i8x16_lt_u(v, space),
    )
    if @v128.i8x16_bitmask(special) == 0 {
      total = total + 16
    } else {
      for j in 0..<16 {
        total = total + escape_cost(bytes[i + j])
      }
    }
    i = i + 16
  }
  while i < len {
    total = total + escape_cost(bytes[i])
    i = i + 1
  }
  // pass 2: emit
  let out : FixedArray[Byte] = FixedArray::make(total, 0)
  let mut outpos = 0
  i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let special = @v128.v128_or_(
      @v128.v128_or_(@v128.i8x16_eq(v, quote), @v128.i8x16_eq(v, backslash)),
      @v128.i8x16_lt_u(v, space),
    )
    if @v128.i8x16_bitmask(special) == 0 {
      for j in 0..<16 {
        out[outpos + j] = bytes[i + j]
      }
      outpos = outpos + 16
    } else {
      for j in 0..<16 {
        outpos = write_escaped(out, outpos, bytes[i + j])
      }
    }
    i = i + 16
  }
  while i < len {
    outpos = write_escaped(out, outpos, bytes[i])
    i = i + 1
  }
  out
}
