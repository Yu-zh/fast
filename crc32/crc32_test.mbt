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
/// Reference bitwise CRC-32 (no table), for cross-checking.
fn crc_bitwise(data : FixedArray[Byte]) -> UInt {
  let mut crc = 0xFFFFFFFFU
  for i in 0..<data.length() {
    crc = crc ^ data[i].to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) != 0U { 0xEDB88320U ^ (crc >> 1) } else { crc >> 1 }
    }
  }
  crc ^ 0xFFFFFFFFU
}

///|
test "crc32 known values" {
  @test.assert_eq(@crc32.checksum(of(b"")), 0U)
  @test.assert_eq(@crc32.checksum(of(b"123456789")), 0xCBF43926U)
  @test.assert_eq(
    @crc32.checksum(of(b"The quick brown fox jumps over the lazy dog")),
    0x414FA339U,
  )
}

///|
test "crc32 matches bitwise reference across lengths" {
  for len in [0, 1, 15, 16, 17, 64, 255, 1000] {
    let data : FixedArray[Byte] = FixedArray::make(len, 0)
    let mut state = 0x2545f491U
    for i in 0..<len {
      state = state ^ (state << 13)
      state = state ^ (state >> 17)
      state = state ^ (state << 5)
      data[i] = (state & 0xff).to_byte()
    }
    @test.assert_eq(@crc32.checksum(data), crc_bitwise(data))
  }
}
