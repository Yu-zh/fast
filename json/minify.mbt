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

// JSON minification: drop insignificant whitespace using the same SIMD
// "stage 1" classification as `structural_indices`. Whitespace inside string
// literals is preserved by reusing the in-string mask (quote prefix-xor with
// backslash-escape handling); a stride with no droppable whitespace is bulk
// copied.

///|
/// Removes all insignificant whitespace (space, tab, line feed, carriage
/// return outside of strings) from a UTF-8 JSON document, preserving string
/// contents byte-for-byte. Returns `None` if a string is left unterminated at
/// end of input. Structural validity is otherwise not checked.
pub fn minify(bytes : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = bytes.length()
  let out : FixedArray[Byte] = FixedArray::make(len, 0)
  let mut outpos = 0
  let mut prev_in_string = 0UL
  let mut prev_escaped = 0UL
  let mut base = 0
  while base < len {
    let valid = if len - base >= 64 { 64 } else { len - base }
    let (packed0, packed1, packed2, packed3) = if len - base >= 64 {
      (
        block_masks(@v128.v128_load(bytes, base)),
        block_masks(@v128.v128_load(bytes, base + 16)),
        block_masks(@v128.v128_load(bytes, base + 32)),
        block_masks(@v128.v128_load(bytes, base + 48)),
      )
    } else {
      let tail : FixedArray[Byte] = FixedArray::make(64, b' ')
      for j in 0..<valid {
        tail[j] = bytes[base + j]
      }
      (
        block_masks(@v128.v128_load(tail, 0)),
        block_masks(@v128.v128_load(tail, 16)),
        block_masks(@v128.v128_load(tail, 32)),
        block_masks(@v128.v128_load(tail, 48)),
      )
    }
    let lane = 0xffffUL
    let ws = ((packed0 >> 16) & lane) |
      (((packed1 >> 16) & lane) << 16) |
      (((packed2 >> 16) & lane) << 32) |
      (((packed3 >> 16) & lane) << 48)
    let quote_raw = ((packed0 >> 32) & lane) |
      (((packed1 >> 32) & lane) << 16) |
      (((packed2 >> 32) & lane) << 32) |
      (((packed3 >> 32) & lane) << 48)
    let backslash_raw = ((packed0 >> 48) & lane) |
      (((packed1 >> 48) & lane) << 16) |
      (((packed2 >> 48) & lane) << 32) |
      (((packed3 >> 48) & lane) << 48)
    let backslash = backslash_raw & prev_escaped.lnot()
    let follows_escape = (backslash << 1) | prev_escaped
    let even_bits = 0x5555555555555555UL
    let odd_sequence_starts = backslash &
      even_bits.lnot() &
      follows_escape.lnot()
    let sum = odd_sequence_starts + backslash
    prev_escaped = if sum < odd_sequence_starts { 1UL } else { 0UL }
    let escaped = (even_bits ^ (sum << 1)) & follows_escape
    let quote = quote_raw & escaped.lnot()
    let in_string = prefix_xor(quote) ^ prev_in_string
    prev_in_string = (in_string.reinterpret_as_int64() >> 63).reinterpret_as_uint64()
    let drop = ws & in_string.lnot()
    if valid == 64 && drop == 0UL {
      for j in 0..<64 {
        out[outpos + j] = bytes[base + j]
      }
      outpos = outpos + 64
    } else {
      for j in 0..<valid {
        if ((drop >> j) & 1UL) == 0UL {
          out[outpos] = bytes[base + j]
          outpos = outpos + 1
        }
      }
    }
    base = base + 64
  }
  if prev_in_string != 0UL {
    return None
  }
  if outpos == len {
    return Some(out)
  }
  let trimmed : FixedArray[Byte] = FixedArray::make(outpos, 0)
  for j in 0..<outpos {
    trimmed[j] = out[j]
  }
  Some(trimmed)
}
