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

// Codepoint counting and Latin-1 (ISO-8859-1) transcoding. Counting exploits
// that codepoints start at every non-continuation byte, so `i8x16_bitmask` of
// the high bits drives a `popcnt`. Latin-1 -> UTF-8 expands bytes >= 0x80 into
// two bytes, with a `bitmask`-detected all-ASCII fast path and exact two-pass
// sizing.

///|
/// Counts the Unicode codepoints in `bytes`, assuming it is valid UTF-8.
/// Equivalent to counting bytes that are not UTF-8 continuation bytes
/// (`(b & 0xC0) != 0x80`).
pub fn count_codepoints(bytes : FixedArray[Byte]) -> Int {
  let len = bytes.length()
  let high2 = @v128.i8x16_splat(0xC0)
  let cont = @v128.i8x16_splat(0x80)
  let mut count = 0
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let is_cont = @v128.i8x16_eq(@v128.v128_and_(v, high2), cont)
    count = count + 16 - @v128.i8x16_bitmask(is_cont).popcnt()
    i = i + 16
  }
  while i < len {
    if (bytes[i] & 0xC0) != 0x80 {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
/// Transcodes Latin-1 (ISO-8859-1) bytes to UTF-8. Bytes < 0x80 are copied;
/// bytes >= 0x80 become a two-byte sequence.
pub fn latin1_to_utf8(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  // pass 1: each byte >= 0x80 (high bit set) costs one extra output byte
  let mut extra = 0
  let mut i = 0
  while i + 16 <= len {
    extra = extra + @v128.i8x16_bitmask(@v128.v128_load(bytes, i)).popcnt()
    i = i + 16
  }
  while i < len {
    if bytes[i] >= 0x80 {
      extra = extra + 1
    }
    i = i + 1
  }
  // pass 2: emit, bulk-copying all-ASCII chunks
  let out : FixedArray[Byte] = FixedArray::make(len + extra, 0)
  let mut o = 0
  i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(v) == 0 {
      @v128.v128_store(out, o, v)
      o = o + 16
    } else {
      for j in 0..<16 {
        let b = bytes[i + j].to_int()
        if b < 0x80 {
          out[o] = b.to_byte()
          o = o + 1
        } else {
          out[o] = (0xC0 | (b >> 6)).to_byte()
          out[o + 1] = (0x80 | (b & 0x3F)).to_byte()
          o = o + 2
        }
      }
    }
    i = i + 16
  }
  while i < len {
    let b = bytes[i].to_int()
    if b < 0x80 {
      out[o] = b.to_byte()
      o = o + 1
    } else {
      out[o] = (0xC0 | (b >> 6)).to_byte()
      out[o + 1] = (0x80 | (b & 0x3F)).to_byte()
      o = o + 2
    }
    i = i + 1
  }
  out
}

///|
/// Transcodes UTF-8 to Latin-1 (ISO-8859-1). Returns `None` if any codepoint
/// is above U+00FF or the input is not valid UTF-8 within that range.
pub fn utf8_to_latin1(bytes : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = bytes.length()
  let out : FixedArray[Byte] = FixedArray::make(len, 0)
  let mut o = 0
  let mut i = 0
  // fast path: copy whole all-ASCII chunks until the first high byte
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(v) == 0 {
      @v128.v128_store(out, o, v)
      o = o + 16
      i = i + 16
    } else {
      break
    }
  }
  while i < len {
    let b = bytes[i].to_int()
    if b < 0x80 {
      out[o] = b.to_byte()
      o = o + 1
      i = i + 1
    } else if (b == 0xC2 || b == 0xC3) &&
      i + 1 < len &&
      bytes[i + 1] >= 0x80 &&
      bytes[i + 1] <= 0xBF {
      let cp = ((b & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      out[o] = cp.to_byte()
      o = o + 1
      i = i + 2
    } else {
      return None
    }
  }
  if o == len {
    return Some(out)
  }
  let trimmed : FixedArray[Byte] = FixedArray::make(o, 0)
  for k in 0..<o {
    trimmed[k] = out[k]
  }
  Some(trimmed)
}
