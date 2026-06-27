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

// SIMD substring search, the generalization of `memchr` to multi-byte
// needles (the "generic SIMD" / Muła approach used by Rust's
// `memchr::memmem` and Go's `bytes.Index`): broadcast the needle's first and
// last byte, AND their per-window equality masks to find candidate offsets,
// then verify each candidate with a full comparison.

///|
fn matches_at(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
  pos : Int,
) -> Bool {
  for k in 0..<needle.length() {
    if haystack[pos + k] != needle[k] {
      return false
    }
  }
  true
}

///|
/// Returns the index of the first occurrence of `needle` in `haystack` at or
/// after `from`, or `None` if it does not occur. An empty needle matches at
/// `from`.
pub fn find(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
  from? : Int = 0,
) -> Int? {
  let n = haystack.length()
  let m = needle.length()
  let start = if from < 0 { 0 } else { from }
  if m == 0 {
    return Some(if start <= n { start } else { n })
  }
  if start + m > n {
    return None
  }
  let first = @v128.i8x16_splat(needle[0])
  let last = @v128.i8x16_splat(needle[m - 1])
  let mut i = start
  // The last-byte probe loads 16 bytes starting at i + m - 1.
  while i + m + 15 <= n {
    let eq = @v128.v128_and_(
      @v128.i8x16_eq(@v128.v128_load(haystack, i), first),
      @v128.i8x16_eq(@v128.v128_load(haystack, i + m - 1), last),
    )
    let mut mask = @v128.i8x16_bitmask(eq)
    while mask != 0 {
      let k = mask.ctz()
      if matches_at(haystack, needle, i + k) {
        return Some(i + k)
      }
      mask = mask & (mask - 1)
    }
    i = i + 16
  }
  while i + m <= n {
    if matches_at(haystack, needle, i) {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Returns whether `needle` occurs anywhere in `haystack`.
pub fn contains(haystack : FixedArray[Byte], needle : FixedArray[Byte]) -> Bool {
  find(haystack, needle) is Some(_)
}

///|
/// Returns the index of the last occurrence of `needle` in `haystack`, or
/// `None` if it does not occur. An empty needle matches at the end.
pub fn find_last(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
) -> Int? {
  let n = haystack.length()
  let m = needle.length()
  if m == 0 {
    return Some(n)
  }
  if m > n {
    return None
  }
  // Valid starts are [0, n - m]; probe the needle's first byte over them.
  let limit = n - m + 1
  let probe = @v128.i8x16_splat(needle[0])
  let mut hi = limit
  while hi - 16 >= 0 {
    let mut mask = @v128.i8x16_bitmask(
      @v128.i8x16_eq(@v128.v128_load(haystack, hi - 16), probe),
    )
    while mask != 0 {
      let bit = 31 - mask.clz()
      let pos = hi - 16 + bit
      if matches_at(haystack, needle, pos) {
        return Some(pos)
      }
      mask = mask & ((1 << bit) - 1)
    }
    hi = hi - 16
  }
  for p = hi - 1; p >= 0; p = p - 1 {
    if haystack[p] == needle[0] && matches_at(haystack, needle, p) {
      return Some(p)
    }
  }
  None
}

///|
/// Counts the non-overlapping occurrences of `needle` in `haystack`,
/// scanning left to right and advancing past each match.
pub fn count(haystack : FixedArray[Byte], needle : FixedArray[Byte]) -> Int {
  let n = haystack.length()
  let m = needle.length()
  if m == 0 {
    return n + 1
  }
  let mut total = 0
  let mut pos = 0
  while pos + m <= n {
    match find(haystack, needle, from=pos) {
      Some(idx) => {
        total = total + 1
        pos = idx + m
      }
      None => break
    }
  }
  total
}
