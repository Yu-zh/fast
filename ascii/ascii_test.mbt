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
test "find_non_ascii and all_ascii" {
  let ascii : FixedArray[Byte] = FixedArray::make(40, b'x')
  inspect(@ascii.all_ascii(ascii), content="true")
  @test.assert_eq(@ascii.find_non_ascii(ascii), None)
  // a non-ASCII byte at every position, across chunk boundaries
  for len in [1, 15, 16, 17, 32, 33] {
    for pos in 0..<len {
      let bytes : FixedArray[Byte] = FixedArray::make(len, b'x')
      bytes[pos] = 0xc3
      @test.assert_eq(@ascii.find_non_ascii(bytes), Some(pos))
      assert_false(@ascii.all_ascii(bytes))
      @test.assert_eq(@ascii.find_non_ascii(bytes, from=pos + 1), None)
    }
  }
  inspect(@ascii.all_ascii(FixedArray::make(0, b'\x00')), content="true")
}

///|
test "skip_whitespace" {
  let bytes : FixedArray[Byte] = [
    b' ', b' ', b'\t', b'\r', b'\n', b' ', b' ', b'x', b' ', b' ',
  ]
  inspect(@ascii.skip_whitespace(bytes), content="7")
  inspect(@ascii.skip_whitespace(bytes, from=8), content="10")
  inspect(@ascii.skip_whitespace(([b'x'] : FixedArray[Byte])), content="0")
  inspect(@ascii.skip_whitespace(FixedArray::make(0, b'\x00')), content="0")
  // all-whitespace buffer longer than one chunk
  let spaces = FixedArray::make(37, b' ')
  inspect(@ascii.skip_whitespace(spaces), content="37")
  // first non-whitespace at every position across chunk boundaries
  for len in [1, 15, 16, 17, 32, 33] {
    for pos in 0..<len {
      let bytes = FixedArray::make(len, b' ')
      bytes[pos] = b'{'
      @test.assert_eq(@ascii.skip_whitespace(bytes), pos)
    }
  }
}

///|
test "to_lower_ascii" {
  let bytes : FixedArray[Byte] = FixedArray::make(33, b'\x00')
  for i in 0..<33 {
    bytes[i] = (b'A' + (i % 26).to_byte() : Byte)
  }
  @ascii.to_lower_ascii(bytes)
  for i in 0..<33 {
    @test.assert_eq(bytes[i], b'a' + (i % 26).to_byte())
  }
  // every byte value: only A-Z may change, and only by the case bit
  let all : FixedArray[Byte] = FixedArray::make(256, b'\x00')
  for i in 0..<256 {
    all[i] = i.to_byte()
  }
  @ascii.to_lower_ascii(all)
  for i in 0..<256 {
    if i >= 0x41 && i <= 0x5a {
      @test.assert_eq(all[i], (i + 0x20).to_byte())
    } else {
      @test.assert_eq(all[i], i.to_byte())
    }
  }
}
