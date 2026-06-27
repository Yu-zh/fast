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
fn of(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  for i in 0..<s.length() {
    out[i] = s[i]
  }
  out
}

///|
fn find_scalar(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
  from : Int,
) -> Int? {
  let n = haystack.length()
  let m = needle.length()
  for i in from..<=(n - m) {
    let mut ok = true
    for k in 0..<m {
      if haystack[i + k] != needle[k] {
        ok = false
        break
      }
    }
    if ok {
      return Some(i)
    }
  }
  None
}

///|
fn find_last_scalar(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
) -> Int? {
  let n = haystack.length()
  let m = needle.length()
  for i = n - m; i >= 0; i = i - 1 {
    let mut ok = true
    for k in 0..<m {
      if haystack[i + k] != needle[k] {
        ok = false
        break
      }
    }
    if ok {
      return Some(i)
    }
  }
  None
}

///|
test "find known cases" {
  let h = of(b"the quick brown fox jumps over the lazy dog")
  @test.assert_eq(@memmem.find(h, of(b"quick")), Some(4))
  @test.assert_eq(@memmem.find(h, of(b"the")), Some(0))
  @test.assert_eq(@memmem.find(h, of(b"the"), from=1), Some(31))
  @test.assert_eq(@memmem.find(h, of(b"dog")), Some(40))
  @test.assert_eq(@memmem.find(h, of(b"cat")), None)
  @test.assert_eq(@memmem.find(h, of(b"")), Some(0))
  @test.assert_eq(@memmem.find_last(h, of(b"the")), Some(31))
  @test.assert_eq(@memmem.find_last(h, of(b"o")), Some(41))
  @test.assert_eq(@memmem.contains(h, of(b"jumps")), true)
  @test.assert_eq(@memmem.contains(h, of(b"jumped")), false)
}

///|
test "count non-overlapping" {
  @test.assert_eq(@memmem.count(of(b"aaaa"), of(b"aa")), 2)
  @test.assert_eq(@memmem.count(of(b"ababab"), of(b"ab")), 3)
  @test.assert_eq(@memmem.count(of(b"aaaaa"), of(b"aa")), 2)
  @test.assert_eq(@memmem.count(of(b"abcabcabc"), of(b"abc")), 3)
  @test.assert_eq(@memmem.count(of(b"xxxxxx"), of(b"y")), 0)
}

///|
/// A long buffer that exercises the SIMD body, the candidate-verification
/// inner loop, and the scalar tail, checked against the scalar reference for
/// many needles at many alignments.
test "find matches scalar over a long haystack" {
  let n = 300
  let haystack : FixedArray[Byte] = FixedArray::make(n, 0)
  for i in 0..<n {
    // a small alphabet makes false candidates (matching first+last) common
    haystack[i] = b'a' + ((i * 7 + i / 5) % 4).to_byte()
  }
  let needles = [
    of(b"a"),
    of(b"ab"),
    of(b"abc"),
    of(b"aa"),
    of(b"abcd"),
    of(b"dcba"),
    of(b"aaaa"),
    of(b"abababababababababab"),
    of(b"zzz"),
  ]
  for needle in needles {
    for from in [0, 1, 7, 16, 17, 33] {
      @test.assert_eq(
        @memmem.find(haystack, needle, from~),
        find_scalar(haystack, needle, from),
      )
    }
    @test.assert_eq(
      @memmem.find_last(haystack, needle),
      find_last_scalar(haystack, needle),
    )
  }
}

///|
test "find at and across block boundaries" {
  // place a needle ending exactly at a 16-byte boundary and just past it
  for offset in [13, 14, 15, 16, 17, 31, 32] {
    let n = 64
    let haystack : FixedArray[Byte] = FixedArray::make(n, b'.')
    let needle = of(b"NEEDLE")
    for k in 0..<needle.length() {
      haystack[offset + k] = needle[k]
    }
    @test.assert_eq(@memmem.find(haystack, needle), Some(offset))
    @test.assert_eq(@memmem.find_last(haystack, needle), Some(offset))
  }
}

///|
test "needle longer than haystack" {
  @test.assert_eq(@memmem.find(of(b"ab"), of(b"abc")), None)
  @test.assert_eq(@memmem.find_last(of(b"ab"), of(b"abc")), None)
  @test.assert_eq(@memmem.count(of(b"ab"), of(b"abc")), 0)
}
