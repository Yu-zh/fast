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

// SIMD CSV structural scanning, the simdjson "stage 1" idea applied to
// RFC 4180 CSV. Per 64-byte stride the delimiter, newline and quote bytes
// are classified into bit masks; a prefix-XOR over the quote bits marks the
// interior of quoted fields (and, because a doubled `""` toggles twice, it
// handles escaped quotes for free). Field and record separators inside
// quoted fields are then masked out. Inputs are assumed well formed per
// RFC 4180 (quotes only delimit whole fields).

///|
/// XOR prefix sum over bits: bit i becomes the parity of bits 0..=i.
fn prefix_xor(mask : UInt64) -> UInt64 {
  let mut x = mask
  x = x ^ (x << 1)
  x = x ^ (x << 2)
  x = x ^ (x << 4)
  x = x ^ (x << 8)
  x = x ^ (x << 16)
  x = x ^ (x << 32)
  x
}

///|
/// Per-16-byte classification packed into one word: delim | nl<<16 | quote<<32.
fn block_masks(v : V128, delim : V128) -> UInt64 {
  let d = @v128.i8x16_bitmask(@v128.i8x16_eq(v, delim)).to_uint64()
  let nl = @v128.i8x16_bitmask(@v128.i8x16_eq(v, @v128.i8x16_splat(b'\n'))).to_uint64()
  let q = @v128.i8x16_bitmask(@v128.i8x16_eq(v, @v128.i8x16_splat(b'"'))).to_uint64()
  d | (nl << 16) | (q << 32)
}

///|
/// Returns the offsets of every field separator (the delimiter) and record
/// separator (line feed) that lies outside a quoted field, in ascending
/// order. Returns `None` if a quoted field is left open at end of input.
pub fn unquoted_positions(
  bytes : FixedArray[Byte],
  delimiter? : Byte = b',',
) -> Array[Int]? {
  let len = bytes.length()
  let out : Array[Int] = Array::new(capacity=len / 8 + 4)
  let delim = @v128.i8x16_splat(delimiter)
  let mut prev_in_quote = 0UL
  let mut base = 0
  while base < len {
    let valid = if len - base >= 64 { 64 } else { len - base }
    let (p0, p1, p2, p3) = if len - base >= 64 {
      (
        block_masks(@v128.v128_load(bytes, base), delim),
        block_masks(@v128.v128_load(bytes, base + 16), delim),
        block_masks(@v128.v128_load(bytes, base + 32), delim),
        block_masks(@v128.v128_load(bytes, base + 48), delim),
      )
    } else {
      let tail : FixedArray[Byte] = FixedArray::make(64, 0)
      for j in 0..<valid {
        tail[j] = bytes[base + j]
      }
      (
        block_masks(@v128.v128_load(tail, 0), delim),
        block_masks(@v128.v128_load(tail, 16), delim),
        block_masks(@v128.v128_load(tail, 32), delim),
        block_masks(@v128.v128_load(tail, 48), delim),
      )
    }
    let lane = 0xffffUL
    let delim_w = (p0 & lane) |
      ((p1 & lane) << 16) |
      ((p2 & lane) << 32) |
      ((p3 & lane) << 48)
    let nl_w = ((p0 >> 16) & lane) |
      (((p1 >> 16) & lane) << 16) |
      (((p2 >> 16) & lane) << 32) |
      (((p3 >> 16) & lane) << 48)
    let quote_w = ((p0 >> 32) & lane) |
      (((p1 >> 32) & lane) << 16) |
      (((p2 >> 32) & lane) << 32) |
      (((p3 >> 32) & lane) << 48)
    let in_quote = prefix_xor(quote_w) ^ prev_in_quote
    prev_in_quote = (in_quote.reinterpret_as_int64() >> 63).reinterpret_as_uint64()
    let valid_mask = if valid == 64 {
      0xffffffffffffffffUL
    } else {
      (1UL << valid) - 1UL
    }
    let mut marks = (delim_w | nl_w) & in_quote.lnot() & valid_mask
    while marks != 0UL {
      out.push(base + marks.ctz())
      marks = marks & (marks - 1)
    }
    base = base + 64
  }
  if prev_in_quote != 0UL {
    return None
  }
  Some(out)
}

///|
/// Splits `bytes` into records of fields, where each field is the raw
/// `(start, end)` byte range (quotes around quoted fields are kept; callers
/// unquote as needed). A trailing `\r` before a record's `\n` is trimmed, and
/// a final trailing newline does not produce an empty record. Returns `None`
/// if a quoted field is left open at end of input.
pub fn split_records(
  bytes : FixedArray[Byte],
  delimiter? : Byte = b',',
) -> Array[Array[(Int, Int)]]? {
  guard unquoted_positions(bytes, delimiter~) is Some(marks) else {
    return None
  }
  let len = bytes.length()
  let rows : Array[Array[(Int, Int)]] = []
  let mut row : Array[(Int, Int)] = []
  let mut start = 0
  for mark in marks {
    if bytes[mark] == delimiter {
      row.push((start, mark))
      start = mark + 1
    } else {
      let mut end = mark
      if end > start && bytes[end - 1] == b'\r' {
        end = end - 1
      }
      row.push((start, end))
      rows.push(row)
      row = []
      start = mark + 1
    }
  }
  if start < len || row.length() > 0 {
    let mut end = len
    if end > start && bytes[end - 1] == b'\r' {
      end = end - 1
    }
    row.push((start, end))
    rows.push(row)
  }
  Some(rows)
}
