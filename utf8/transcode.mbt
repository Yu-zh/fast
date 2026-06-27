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

// simdutf-style transcoding between UTF-8 and UTF-16LE byte buffers
// (https://github.com/simdutf/simdutf). Conversions validate while
// transcoding in a single pass: ASCII converts in bulk (i16x8 extend /
// narrow, with 64-byte superblocks and ASCII-prefix splitting around
// multi-byte sequences), and the scalar path checks each sequence as it
// decodes. Sizing is optimistic: phase 1 converts leading ASCII into a
// buffer that is exact for all-ASCII input (no counting pass, no copy);
// on the first wider block, phase 2 counts only the remainder, allocates
// the exact result, and blits the prefix across. For invalid input the
// remainder count may be wrong, but conversion aborts at the first bad
// sequence and every write before that point is exactly accounted, so
// the store-ahead guards suffice. Counting functions assume valid input,
// matching simdutf's contract.

///|
/// Validates a UTF-16LE byte buffer: even length and correctly paired
/// surrogates. Eight code units are checked per step; a high surrogate in
/// the last lane carries into the next block.
pub fn validate_utf16le(bytes : FixedArray[Byte]) -> Bool {
  let len = bytes.length()
  if len % 2 != 0 {
    return false
  }
  let mut pending = 0 // 1 when the previous unit was a high surrogate
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let masked = @v128.v128_and_(v, @v128.i16x8_splat(0xfc00))
    let hi_bits = @v128.i16x8_bitmask(
      @v128.i16x8_eq(masked, @v128.i16x8_splat(0xd800)),
    )
    let lo_bits = @v128.i16x8_bitmask(
      @v128.i16x8_eq(masked, @v128.i16x8_splat(0xdc00)),
    )
    // a high surrogate in lane j demands a low surrogate in lane j+1, and
    // nothing else may be a low surrogate
    if (((hi_bits << 1) | pending) & 0xff) != lo_bits {
      return false
    }
    pending = hi_bits >> 7
    i = i + 16
  }
  while i < len {
    let u = bytes[i].to_int() | (bytes[i + 1].to_int() << 8)
    if pending == 1 {
      guard u >= 0xdc00 && u <= 0xdfff else { return false }
      pending = 0
    } else if u >= 0xd800 && u <= 0xdbff {
      pending = 1
    } else if u >= 0xdc00 && u <= 0xdfff {
      return false
    }
    i = i + 2
  }
  pending == 0
}

///|
fn utf16_units_from_utf8_at(bytes : FixedArray[Byte], from : Int) -> Int {
  let len = bytes.length()
  let mut units = 0
  let mut i = from
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let cont = @v128.i8x16_eq(
      @v128.v128_and_(v, @v128.i8x16_splat(0xc0)),
      @v128.i8x16_splat(0x80),
    )
    let lead4 = @v128.i8x16_ge_u(v, @v128.i8x16_splat(0xf0))
    units = units +
      16 -
      @v128.i8x16_bitmask(cont).popcnt() +
      @v128.i8x16_bitmask(lead4).popcnt()
    i = i + 16
  }
  while i < len {
    let b = bytes[i]
    if (b & 0xc0) != 0x80 {
      units = units + 1
    }
    if b >= 0xf0 {
      units = units + 1
    }
    i = i + 1
  }
  units
}

///|
/// Number of UTF-16 code units needed for valid UTF-8 input: one per
/// non-continuation byte, plus one extra per 4-byte sequence (surrogate
/// pair). Assumes the input is valid UTF-8.
pub fn utf16_length_from_utf8(bytes : FixedArray[Byte]) -> Int {
  utf16_units_from_utf8_at(bytes, 0)
}

///|
fn utf8_bytes_from_utf16le_at(bytes : FixedArray[Byte], from : Int) -> Int {
  let len = bytes.length()
  let mut count = 0
  let mut i = from
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let lt80 = @v128.i16x8_lt_u(v, @v128.i16x8_splat(0x0080))
    let lt800 = @v128.i16x8_lt_u(v, @v128.i16x8_splat(0x0800))
    let hi = @v128.i16x8_eq(
      @v128.v128_and_(v, @v128.i16x8_splat(0xfc00)),
      @v128.i16x8_splat(0xd800),
    )
    count = count +
      24 -
      @v128.i16x8_bitmask(lt800).popcnt() -
      @v128.i16x8_bitmask(lt80).popcnt() -
      2 * @v128.i16x8_bitmask(hi).popcnt()
    i = i + 16
  }
  while i < len {
    let u = bytes[i].to_int() | (bytes[i + 1].to_int() << 8)
    count = count +
      (if u < 0x80 {
        1
      } else if u < 0x800 {
        2
      } else if u >= 0xd800 && u <= 0xdbff {
        // high surrogate: the pair contributes 4 in total, low adds 3
        1
      } else {
        3
      })
    i = i + 2
  }
  count
}

///|
/// Number of UTF-8 bytes needed for valid UTF-16LE input. Each unit costs
/// three bytes, minus one if below U+0800, minus another if ASCII; each
/// surrogate pair (counted 3+3) actually encodes as 4, so high surrogates
/// subtract two. Assumes the input is valid UTF-16LE.
pub fn utf8_length_from_utf16le(bytes : FixedArray[Byte]) -> Int {
  utf8_bytes_from_utf16le_at(bytes, 0)
}

///|
/// Single-load LE u16 read, mirroring Bytes::unsafe_read_uint16_le for
/// FixedArray[Byte] (same representation on every backend).
#borrow(bytes)
#intrinsic("%bytes.unsafe_read_uint16_le")
fn read_u16le(bytes : FixedArray[Byte], index : Int) -> UInt16 {
  bytes.unsafe_get(index).to_uint16() |
  (bytes.unsafe_get(index + 1).to_uint16() << 8)
}

///|
fn read_unit(bytes : FixedArray[Byte], index : Int) -> Int {
  read_u16le(bytes, index).to_int()
}

///|
/// Decodes and validates one UTF-8 sequence (RFC 3629: overlongs,
/// surrogates, and values above U+10FFFF rejected). Returns
/// `(width << 21) | codepoint`, packed to stay allocation-free, or -1 when
/// the sequence is invalid or truncated.
fn utf8_decode_checked(bytes : FixedArray[Byte], i : Int, len : Int) -> Int {
  let b0 = bytes.unsafe_get(i).to_int()
  if b0 < 0x80 {
    return (1 << 21) | b0
  }
  if b0 < 0xc2 {
    return -1
  }
  if b0 < 0xe0 {
    if i + 1 >= len {
      return -1
    }
    let b1 = bytes.unsafe_get(i + 1).to_int()
    if (b1 & 0xc0) != 0x80 {
      return -1
    }
    return (2 << 21) | ((b0 & 0x1f) << 6) | (b1 & 0x3f)
  }
  if b0 < 0xf0 {
    if i + 2 >= len {
      return -1
    }
    let b1 = bytes.unsafe_get(i + 1).to_int()
    let b2 = bytes.unsafe_get(i + 2).to_int()
    let lo = if b0 == 0xe0 { 0xa0 } else { 0x80 }
    let hi = if b0 == 0xed { 0x9f } else { 0xbf }
    if b1 < lo || b1 > hi || (b2 & 0xc0) != 0x80 {
      return -1
    }
    return (3 << 21) | ((b0 & 0x0f) << 12) | ((b1 & 0x3f) << 6) | (b2 & 0x3f)
  }
  if b0 < 0xf5 {
    if i + 3 >= len {
      return -1
    }
    let b1 = bytes.unsafe_get(i + 1).to_int()
    let b2 = bytes.unsafe_get(i + 2).to_int()
    let b3 = bytes.unsafe_get(i + 3).to_int()
    let lo = if b0 == 0xf0 { 0x90 } else { 0x80 }
    let hi = if b0 == 0xf4 { 0x8f } else { 0xbf }
    if b1 < lo || b1 > hi || (b2 & 0xc0) != 0x80 || (b3 & 0xc0) != 0x80 {
      return -1
    }
    return (4 << 21) |
      ((b0 & 0x07) << 18) |
      ((b1 & 0x3f) << 12) |
      ((b2 & 0x3f) << 6) |
      (b3 & 0x3f)
  }
  -1
}

///|
/// Writes one code point as UTF-16LE and returns the new output offset.
fn emit_utf16le(out : FixedArray[Byte], k : Int, cp : Int) -> Int {
  if cp < 0x10000 {
    out.unsafe_write_uint16_le(k, cp.to_uint16())
    k + 2
  } else {
    let v = cp - 0x10000
    let hi = 0xd800 | (v >> 10)
    let lo = 0xdc00 | (v & 0x3ff)
    out.unsafe_write_uint32_le(k, (hi | (lo << 16)).reinterpret_as_uint())
    k + 4
  }
}

///|
/// Converts UTF-8 to UTF-16LE in a single validating pass. Returns `None`
/// when the input is not valid UTF-8.
///
/// Phase 1 optimistically bulk-converts leading ASCII into a buffer that
/// is exactly sized when the whole input is ASCII, so the common case
/// needs no counting pass and no copy. On the first non-ASCII block,
/// phase 2 counts only the remaining bytes, allocates the exact result,
/// blits the converted prefix, and continues with ASCII-prefix splitting
/// around scalar-checked multi-byte sequences.
pub fn convert_utf8_to_utf16le(bytes : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = bytes.length()
  let mut ascii_buf : FixedArray[Byte] = FixedArray::make(0, 0)
  let mut i = 0
  // probe the first superblock before paying for the optimistic buffer:
  // input that opens with multi-byte text skips phase 1 entirely
  let begins_ascii = len >= 64 &&
    @v128.i8x16_bitmask(
      @v128.v128_or_(
        @v128.v128_or_(@v128.v128_load(bytes, 0), @v128.v128_load(bytes, 16)),
        @v128.v128_or_(@v128.v128_load(bytes, 32), @v128.v128_load(bytes, 48)),
      ),
    ) ==
    0
  if begins_ascii {
    ascii_buf = uninit_bytes(len * 2)
    while i + 64 <= len {
      let v0 = @v128.v128_load(bytes, i)
      let v1 = @v128.v128_load(bytes, i + 16)
      let v2 = @v128.v128_load(bytes, i + 32)
      let v3 = @v128.v128_load(bytes, i + 48)
      let combined = @v128.v128_or_(
        @v128.v128_or_(v0, v1),
        @v128.v128_or_(v2, v3),
      )
      if @v128.i8x16_bitmask(combined) != 0 {
        break
      }
      let k = i * 2
      @v128.v128_store(ascii_buf, k, @v128.i16x8_extend_low_i8x16_u(v0))
      @v128.v128_store(ascii_buf, k + 16, @v128.i16x8_extend_high_i8x16_u(v0))
      @v128.v128_store(ascii_buf, k + 32, @v128.i16x8_extend_low_i8x16_u(v1))
      @v128.v128_store(ascii_buf, k + 48, @v128.i16x8_extend_high_i8x16_u(v1))
      @v128.v128_store(ascii_buf, k + 64, @v128.i16x8_extend_low_i8x16_u(v2))
      @v128.v128_store(ascii_buf, k + 80, @v128.i16x8_extend_high_i8x16_u(v2))
      @v128.v128_store(ascii_buf, k + 96, @v128.i16x8_extend_low_i8x16_u(v3))
      @v128.v128_store(ascii_buf, k + 112, @v128.i16x8_extend_high_i8x16_u(v3))
      i = i + 64
    }
    while i + 16 <= len {
      let v = @v128.v128_load(bytes, i)
      if @v128.i8x16_bitmask(v) != 0 {
        break
      }
      @v128.v128_store(ascii_buf, i * 2, @v128.i16x8_extend_low_i8x16_u(v))
      @v128.v128_store(
        ascii_buf,
        i * 2 + 16,
        @v128.i16x8_extend_high_i8x16_u(v),
      )
      i = i + 16
    }
    if i + 16 > len {
      while i < len && bytes.unsafe_get(i) < 0x80 {
        ascii_buf.unsafe_write_uint16_le(i * 2, bytes.unsafe_get(i).to_uint16())
        i = i + 1
      }
      if i == len {
        return Some(ascii_buf)
      }
    }
  }
  // phase 2: i sits at a sequence boundary with a non-ASCII byte ahead
  let out : FixedArray[Byte] = uninit_bytes(
    i * 2 + utf16_units_from_utf8_at(bytes, i) * 2,
  )
  if i > 0 {
    ascii_buf.blit_to(out, len=i * 2)
  }
  let out_len = out.length()
  let mut k = i * 2
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let mask = @v128.i8x16_bitmask(v)
    if mask == 0 && k + 32 <= out_len {
      @v128.v128_store(out, k, @v128.i16x8_extend_low_i8x16_u(v))
      @v128.v128_store(out, k + 16, @v128.i16x8_extend_high_i8x16_u(v))
      i = i + 16
      k = k + 32
    } else {
      if mask != 0 {
        let prefix = mask.ctz()
        if prefix > 0 && k + 32 <= out_len {
          // bulk-convert the ASCII prefix; the tail of the store is
          // overwritten by whatever comes next
          @v128.v128_store(out, k, @v128.i16x8_extend_low_i8x16_u(v))
          @v128.v128_store(out, k + 16, @v128.i16x8_extend_high_i8x16_u(v))
          i = i + prefix
          k = k + prefix * 2
        }
      }
      let packed = utf8_decode_checked(bytes, i, len)
      if packed < 0 {
        return None
      }
      k = emit_utf16le(out, k, packed & 0x1fffff)
      i = i + (packed >> 21)
    }
  }
  while i < len {
    let packed = utf8_decode_checked(bytes, i, len)
    if packed < 0 {
      return None
    }
    k = emit_utf16le(out, k, packed & 0x1fffff)
    i = i + (packed >> 21)
  }
  Some(out)
}

///|
/// Writes one code point as UTF-8 and returns the new output offset.
fn emit_utf8(out : FixedArray[Byte], k : Int, cp : Int) -> Int {
  if cp < 0x80 {
    out.unsafe_set(k, cp.to_byte())
    k + 1
  } else if cp < 0x800 {
    out.unsafe_set(k, (0xc0 | (cp >> 6)).to_byte())
    out.unsafe_set(k + 1, (0x80 | (cp & 0x3f)).to_byte())
    k + 2
  } else if cp < 0x10000 {
    out.unsafe_set(k, (0xe0 | (cp >> 12)).to_byte())
    out.unsafe_set(k + 1, (0x80 | ((cp >> 6) & 0x3f)).to_byte())
    out.unsafe_set(k + 2, (0x80 | (cp & 0x3f)).to_byte())
    k + 3
  } else {
    let word = 0xf0 |
      (cp >> 18) |
      ((0x80 | ((cp >> 12) & 0x3f)) << 8) |
      ((0x80 | ((cp >> 6) & 0x3f)) << 16) |
      ((0x80 | (cp & 0x3f)) << 24)
    out.unsafe_write_uint32_le(k, word.reinterpret_as_uint())
    k + 4
  }
}

///|
/// Converts UTF-16LE to UTF-8 in a single validating pass. Returns `None`
/// when the input is odd-length or contains unpaired surrogates.
///
/// Phase 1 optimistically narrows leading ASCII units into a buffer that
/// is exactly sized when the whole input is ASCII. On the first wider
/// unit, phase 2 counts only the remaining units, allocates the exact
/// result, blits the converted prefix, and continues with ASCII-prefix
/// splitting around scalar-checked units and surrogate pairs.
pub fn convert_utf16le_to_utf8(bytes : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = bytes.length()
  if len % 2 != 0 {
    return None
  }
  let mut ascii_buf : FixedArray[Byte] = FixedArray::make(0, 0)
  let mut i = 0
  // probe the first superblock before paying for the optimistic buffer
  let begins_ascii = len >= 64 &&
    @v128.i16x8_bitmask(
      @v128.i16x8_ge_u(
        @v128.v128_or_(
          @v128.v128_or_(@v128.v128_load(bytes, 0), @v128.v128_load(bytes, 16)),
          @v128.v128_or_(@v128.v128_load(bytes, 32), @v128.v128_load(bytes, 48)),
        ),
        @v128.i16x8_splat(0x0080),
      ),
    ) ==
    0
  if begins_ascii {
    ascii_buf = uninit_bytes(len / 2)
    while i + 64 <= len {
      let v0 = @v128.v128_load(bytes, i)
      let v1 = @v128.v128_load(bytes, i + 16)
      let v2 = @v128.v128_load(bytes, i + 32)
      let v3 = @v128.v128_load(bytes, i + 48)
      let combined = @v128.v128_or_(
        @v128.v128_or_(v0, v1),
        @v128.v128_or_(v2, v3),
      )
      // OR only sets bits, so every lane of every block is below 0x80
      // exactly when every lane of the OR is
      if @v128.i16x8_bitmask(
          @v128.i16x8_ge_u(combined, @v128.i16x8_splat(0x0080)),
        ) !=
        0 {
        break
      }
      @v128.v128_store(ascii_buf, i / 2, @v128.i8x16_narrow_i16x8_u(v0, v1))
      @v128.v128_store(
        ascii_buf,
        i / 2 + 16,
        @v128.i8x16_narrow_i16x8_u(v2, v3),
      )
      i = i + 64
    }
    while i + 32 <= len {
      let a = @v128.v128_load(bytes, i)
      let b = @v128.v128_load(bytes, i + 16)
      let non_ascii = @v128.i16x8_ge_u(
        @v128.v128_or_(a, b),
        @v128.i16x8_splat(0x0080),
      )
      if @v128.i16x8_bitmask(non_ascii) != 0 {
        break
      }
      @v128.v128_store(ascii_buf, i / 2, @v128.i8x16_narrow_i16x8_u(a, b))
      i = i + 32
    }
    if i + 32 > len {
      while i < len &&
            bytes.unsafe_get(i) < 0x80 &&
            bytes.unsafe_get(i + 1) == 0 {
        ascii_buf.unsafe_set(i / 2, bytes.unsafe_get(i))
        i = i + 2
      }
      if i == len {
        return Some(ascii_buf)
      }
    }
  }
  // phase 2: i sits at a unit boundary with a wider unit ahead
  let out : FixedArray[Byte] = uninit_bytes(
    i / 2 + utf8_bytes_from_utf16le_at(bytes, i),
  )
  if i > 0 {
    ascii_buf.blit_to(out, len=i / 2)
  }
  let out_len = out.length()
  let mut k = i / 2
  while i + 32 <= len {
    let a = @v128.v128_load(bytes, i)
    let b = @v128.v128_load(bytes, i + 16)
    let limit = @v128.i16x8_splat(0x0080)
    let mask = @v128.i16x8_bitmask(@v128.i16x8_ge_u(a, limit)) |
      (@v128.i16x8_bitmask(@v128.i16x8_ge_u(b, limit)) << 8)
    if mask == 0 && k + 16 <= out_len {
      @v128.v128_store(out, k, @v128.i8x16_narrow_i16x8_u(a, b))
      i = i + 32
      k = k + 16
    } else {
      if mask != 0 {
        let prefix = mask.ctz()
        if prefix > 0 && k + 16 <= out_len {
          // bulk-convert the ASCII prefix; the tail of the store is
          // overwritten by whatever comes next
          @v128.v128_store(out, k, @v128.i8x16_narrow_i16x8_u(a, b))
          i = i + prefix * 2
          k = k + prefix
        }
      }
      let u = read_unit(bytes, i)
      if u >= 0xd800 && u <= 0xdbff {
        if i + 3 >= len {
          return None
        }
        let l = read_unit(bytes, i + 2)
        if l < 0xdc00 || l > 0xdfff {
          return None
        }
        k = emit_utf8(out, k, 0x10000 + ((u - 0xd800) << 10) + (l - 0xdc00))
        i = i + 4
      } else if u >= 0xdc00 && u <= 0xdfff {
        return None
      } else {
        k = emit_utf8(out, k, u)
        i = i + 2
      }
    }
  }
  while i < len {
    let u = read_unit(bytes, i)
    if u >= 0xd800 && u <= 0xdbff {
      if i + 3 >= len {
        return None
      }
      let l = read_unit(bytes, i + 2)
      if l < 0xdc00 || l > 0xdfff {
        return None
      }
      k = emit_utf8(out, k, 0x10000 + ((u - 0xd800) << 10) + (l - 0xdc00))
      i = i + 4
    } else if u >= 0xdc00 && u <= 0xdfff {
      return None
    } else {
      k = emit_utf8(out, k, u)
      i = i + 2
    }
  }
  Some(out)
}
