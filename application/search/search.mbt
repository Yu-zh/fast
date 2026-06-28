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

// A grep-like literal search over text, built on `Yu-zh/fast`. Matches are
// found by the SIMD substring search (`memmem.find`, ~20x scalar) and mapped to
// line numbers using SIMD newline scanning (`memchr`). The result is the set of
// matching lines with their 1-based line numbers.

///|
fn slice(d : FixedArray[Byte], start : Int, end : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(end - start, 0)
  for i in 0..<(end - start) {
    out[i] = d[start + i]
  }
  out
}

///|
/// A matching line: its 1-based number and byte range `[start, end)` in the
/// haystack (excluding the trailing newline).
pub struct Match {
  line : Int
  start : Int
  end : Int
}

///|
/// Every newline offset in `h`, ascending.
fn newline_positions(h : FixedArray[Byte]) -> Array[Int] {
  let pos : Array[Int] = []
  let mut from = 0
  while true {
    match @memchr.find_byte(h, b'\n', from~) {
      Some(i) => {
        pos.push(i)
        from = i + 1
      }
      None => break
    }
  }
  pos
}

///|
/// Number of newline offsets strictly less than `off` (i.e. its 0-based line).
fn line_of(nls : Array[Int], off : Int) -> Int {
  let mut lo = 0
  let mut hi = nls.length()
  while lo < hi {
    let mid = (lo + hi) / 2
    if nls[mid] < off {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
/// Offsets of every (non-overlapping) occurrence of `needle` in `haystack`.
pub fn find_all(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
) -> Array[Int] {
  let out : Array[Int] = []
  if needle.length() == 0 {
    return out
  }
  let mut from = 0
  while true {
    match @memmem.find(haystack, needle, from~) {
      Some(off) => {
        out.push(off)
        from = off + needle.length()
      }
      None => break
    }
  }
  out
}

///|
/// Total number of (non-overlapping) matches.
pub fn count(haystack : FixedArray[Byte], needle : FixedArray[Byte]) -> Int {
  @memmem.count(haystack, needle)
}

///|
/// The distinct lines of `haystack` that contain `needle`, in order, each with
/// its 1-based line number.
pub fn search_lines(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
) -> Array[Match] {
  let out : Array[Match] = []
  if needle.length() == 0 {
    return out
  }
  let nls = newline_positions(haystack)
  let n = haystack.length()
  let mut from = 0
  let mut last_line = -1
  while true {
    match @memmem.find(haystack, needle, from~) {
      Some(off) => {
        let line = line_of(nls, off)
        if line != last_line {
          let start = if line == 0 { 0 } else { nls[line - 1] + 1 }
          let end = if line < nls.length() { nls[line] } else { n }
          out.push(Match::{ line: line + 1, start, end })
          last_line = line
        }
        from = off + needle.length()
      }
      None => break
    }
  }
  out
}

///|
/// The bytes of a matching line.
pub fn Match::text(
  self : Match,
  haystack : FixedArray[Byte],
) -> FixedArray[Byte] {
  slice(haystack, self.start, self.end)
}
