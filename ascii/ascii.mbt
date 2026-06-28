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

///|
/// Converts ASCII lowercase letters to uppercase in place; all other bytes
/// (including non-ASCII) are left unchanged.
pub fn to_upper_ascii(bytes : FixedArray[Byte]) -> Unit {
  let len = bytes.length()
  let mut i = 0
  let bias = @v128.i8x16_splat(b'a')
  let range = @v128.i8x16_splat(26)
  let case_bit = @v128.i8x16_splat(0x20)
  while i + 16 <= len {
    let chunk = @v128.v128_load(bytes, i)
    // 'a' <= b <= 'z', then clear the 0x20 case bit on those lanes only
    let lower = @v128.i8x16_lt_u(@v128.i8x16_sub(chunk, bias), range)
    let uppered = @v128.v128_andnot(chunk, @v128.v128_and_(lower, case_bit))
    @v128.v128_store(bytes, i, uppered)
    i = i + 16
  }
  while i < len {
    let b = bytes[i]
    if b >= b'a' && b <= b'z' {
      bytes[i] = b & 0xdf
    }
    i = i + 1
  }
}

///|
/// Folds an ASCII byte to lowercase for case-insensitive comparison: only
/// 'A'-'Z' are shifted, every other byte (including non-ASCII) is unchanged.
fn fold(v : V128) -> V128 {
  let upper = @v128.i8x16_lt_u(
    @v128.i8x16_sub(v, @v128.i8x16_splat(b'A')),
    @v128.i8x16_splat(26),
  )
  @v128.v128_or_(v, @v128.v128_and_(upper, @v128.i8x16_splat(0x20)))
}

///|
/// Returns whether `a` and `b` are equal ignoring ASCII letter case.
pub fn eq_ignore_case(a : FixedArray[Byte], b : FixedArray[Byte]) -> Bool {
  let len = a.length()
  if len != b.length() {
    return false
  }
  let mut i = 0
  while i + 16 <= len {
    let eq = @v128.i8x16_eq(
      fold(@v128.v128_load(a, i)),
      fold(@v128.v128_load(b, i)),
    )
    if @v128.i8x16_bitmask(eq) != 0xffff {
      return false
    }
    i = i + 16
  }
  while i < len {
    let x = a[i]
    let y = b[i]
    let fx = if x >= b'A' && x <= b'Z' { x | 0x20 } else { x }
    let fy = if y >= b'A' && y <= b'Z' { y | 0x20 } else { y }
    if fx != fy {
      return false
    }
    i = i + 1
  }
  true
}
