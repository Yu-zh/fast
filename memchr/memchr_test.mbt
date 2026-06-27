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
fn find_byte_scalar(
  haystack : FixedArray[Byte],
  needle : Byte,
  from? : Int = 0,
) -> Int? {
  for i in from..<haystack.length() {
    if haystack[i] == needle {
      return Some(i)
    }
  }
  None
}

///|
fn find_last_byte_scalar(haystack : FixedArray[Byte], needle : Byte) -> Int? {
  for i = haystack.length() - 1; i >= 0; i = i - 1 {
    if haystack[i] == needle {
      return Some(i)
    }
  }
  None
}

///|
fn count_byte_scalar(haystack : FixedArray[Byte], needle : Byte) -> Int {
  let mut count = 0
  for i in 0..<haystack.length() {
    if haystack[i] == needle {
      count = count + 1
    }
  }
  count
}

///|
/// Deterministic xorshift so the cross-check inputs are reproducible.
fn make_noise(len : Int, seed : UInt) -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
  let mut state = seed | 1
  for i in 0..<len {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = (state & 0xff).to_byte()
  }
  bytes
}

///|
test "find_byte basic" {
  let bytes : FixedArray[Byte] = [b'h', b'e', b'l', b'l', b'o']
  @test.assert_eq(@memchr.find_byte(bytes, b'h'), Some(0))
  @test.assert_eq(@memchr.find_byte(bytes, b'l'), Some(2))
  @test.assert_eq(@memchr.find_byte(bytes, b'l', from=3), Some(3))
  @test.assert_eq(@memchr.find_byte(bytes, b'l', from=4), None)
  @test.assert_eq(@memchr.find_byte(bytes, b'x'), None)
  @test.assert_eq(@memchr.find_byte(bytes, b'h', from=-5), Some(0))
  @test.assert_eq(@memchr.find_byte(FixedArray::make(0, b'\x00'), b'a'), None)
}

///|
test "find_byte chunk boundaries" {
  // needle placed at every position of a buffer spanning several chunks
  for len in [1, 15, 16, 17, 31, 32, 33, 47] {
    for pos in 0..<len {
      let bytes : FixedArray[Byte] = FixedArray::make(len, b'.')
      bytes[pos] = b'!'
      @test.assert_eq(@memchr.find_byte(bytes, b'!'), Some(pos))
      @test.assert_eq(@memchr.find_last_byte(bytes, b'!'), Some(pos))
      @test.assert_eq(@memchr.count_byte(bytes, b'!'), 1)
    }
  }
}

///|
test "cross-check against scalar reference" {
  for seed in 1U..<8U {
    let bytes = make_noise(257, seed * 2654435761U)
    for needle_seed in 0..<8 {
      let needle = ((needle_seed * 37) & 0xff).to_byte()
      @test.assert_eq(
        @memchr.find_byte(bytes, needle),
        find_byte_scalar(bytes, needle),
      )
      @test.assert_eq(
        @memchr.find_byte(bytes, needle, from=100),
        find_byte_scalar(bytes, needle, from=100),
      )
      @test.assert_eq(
        @memchr.find_last_byte(bytes, needle),
        find_last_byte_scalar(bytes, needle),
      )
      @test.assert_eq(
        @memchr.count_byte(bytes, needle),
        count_byte_scalar(bytes, needle),
      )
    }
  }
}

///|
test "count_byte counts duplicates inside one chunk" {
  let bytes : FixedArray[Byte] = FixedArray::make(64, b'a')
  inspect(@memchr.count_byte(bytes, b'a'), content="64")
  inspect(@memchr.count_byte(bytes, b'b'), content="0")
}
