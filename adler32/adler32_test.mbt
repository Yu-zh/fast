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
fn adler_scalar(data : FixedArray[Byte]) -> UInt {
  let mut s1 = 1U
  let mut s2 = 0U
  for i in 0..<data.length() {
    s1 = (s1 + data[i].to_uint()) % 65521U
    s2 = (s2 + s1) % 65521U
  }
  (s2 << 16) | s1
}

///|
test "adler32 known values" {
  @test.assert_eq(@adler32.checksum(of(b"")), 1U)
  @test.assert_eq(@adler32.checksum(of(b"Wikipedia")), 0x11E60398U)
  @test.assert_eq(@adler32.checksum(of(b"abc")), 0x024D0127U)
}

///|
test "adler32 matches scalar across lengths, including past NMAX" {
  for len in [0, 1, 15, 16, 17, 33, 100, 5551, 5552, 5553, 11104, 20000] {
    let data : FixedArray[Byte] = FixedArray::make(len, 0)
    let mut state = 0x2545f491U
    for i in 0..<len {
      state = state ^ (state << 13)
      state = state ^ (state >> 17)
      state = state ^ (state << 5)
      data[i] = (state & 0xff).to_byte()
    }
    @test.assert_eq(@adler32.checksum(data), adler_scalar(data))
  }
}
