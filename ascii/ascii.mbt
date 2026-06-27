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
/// Returns the index of the first non-ASCII byte (>= 0x80) at or after
/// `from`, or `None` if every byte is ASCII.
pub fn find_non_ascii(bytes : FixedArray[Byte], from? : Int = 0) -> Int? {
  let len = bytes.length()
  let mut i = if from < 0 { 0 } else { from }
  while i + 16 <= len {
    let mask = @v128.i8x16_bitmask(@v128.v128_load(bytes, i))
    if mask != 0 {
      return Some(i + mask.ctz())
    }
    i = i + 16
  }
  while i < len {
    if bytes[i] >= 0x80 {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Returns `true` when every byte is ASCII (< 0x80).
pub fn all_ascii(bytes : FixedArray[Byte]) -> Bool {
  find_non_ascii(bytes) is None
}

///|
fn is_json_whitespace(b : Byte) -> Bool {
  b == b' ' || b == b'\t' || b == b'\n' || b == b'\r'
}

///|
/// Returns the index of the first byte at or after `from` that is not JSON
/// whitespace (space, tab, line feed, carriage return). Returns the length
/// of `bytes` when everything from `from` on is whitespace.
pub fn skip_whitespace(bytes : FixedArray[Byte], from? : Int = 0) -> Int {
  let len = bytes.length()
  let mut i = if from < 0 { 0 } else { from }
  let sp = @v128.i8x16_splat(b' ')
  let tab = @v128.i8x16_splat(b'\t')
  let nl = @v128.i8x16_splat(b'\n')
  let cr = @v128.i8x16_splat(b'\r')
  while i + 16 <= len {
    let chunk = @v128.v128_load(bytes, i)
    let ws = @v128.v128_or_(
      @v128.v128_or_(@v128.i8x16_eq(chunk, sp), @v128.i8x16_eq(chunk, tab)),
      @v128.v128_or_(@v128.i8x16_eq(chunk, nl), @v128.i8x16_eq(chunk, cr)),
    )
    let mask = @v128.i8x16_bitmask(ws)
    if mask != 0xffff {
      return i + (mask ^ 0xffff).ctz()
    }
    i = i + 16
  }
  while i < len && is_json_whitespace(bytes[i]) {
    i = i + 1
  }
  i
}

///|
/// Converts ASCII uppercase letters to lowercase in place; all other bytes
/// (including non-ASCII) are left unchanged.
pub fn to_lower_ascii(bytes : FixedArray[Byte]) -> Unit {
  let len = bytes.length()
  let mut i = 0
  // 'A' <= b <= 'Z' is a single unsigned range check after biasing by -'A',
  // since wrapped values below 'A' become large.
  let bias = @v128.i8x16_splat(b'A')
  let range = @v128.i8x16_splat(26)
  let case_bit = @v128.i8x16_splat(0x20)
  while i + 16 <= len {
    let chunk = @v128.v128_load(bytes, i)
    let upper = @v128.i8x16_lt_u(@v128.i8x16_sub(chunk, bias), range)
    let lowered = @v128.v128_or_(chunk, @v128.v128_and_(upper, case_bit))
    @v128.v128_store(bytes, i, lowered)
    i = i + 16
  }
  while i < len {
    let b = bytes[i]
    if b >= b'A' && b <= b'Z' {
      bytes[i] = b | 0x20
    }
    i = i + 1
  }
}
