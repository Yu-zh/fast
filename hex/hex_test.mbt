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
fn encode_scalar(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let digits = b"0123456789abcdef"
  let out : FixedArray[Byte] = FixedArray::make(bytes.length() * 2, 0)
  for i in 0..<bytes.length() {
    out[i * 2] = digits[bytes[i].to_int() >> 4]
    out[i * 2 + 1] = digits[bytes[i].to_int() & 0x0f]
  }
  out
}

///|
test "encode basics" {
  @test.assert_eq(
    @hex.encode(FixedArray::make(0, b'\x00')),
    FixedArray::make(0, b'\x00'),
  )
  @test.assert_eq(
    @hex.encode([b'a', b'b', b'c']),
    ([b'6', b'1', b'6', b'2', b'6', b'3'] : FixedArray[Byte]),
  )
  @test.assert_eq(
    @hex.encode([0x00, 0xff, 0x10, 0x0f]),
    ([b'0', b'0', b'f', b'f', b'1', b'0', b'0', b'f'] : FixedArray[Byte]),
  )
}

///|
test "encode matches scalar for all byte values and odd lengths" {
  for len in [1, 15, 16, 17, 31, 32, 33, 256] {
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = ((i * 7 + 3) & 0xff).to_byte()
    }
    @test.assert_eq(@hex.encode(bytes), encode_scalar(bytes))
  }
}

///|
test "decode round-trips encode" {
  for len in [0, 1, 15, 16, 17, 31, 32, 33, 256] {
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = ((i * 13 + 1) & 0xff).to_byte()
    }
    @test.assert_eq(@hex.decode(@hex.encode(bytes)), Some(bytes))
  }
}

///|
test "decode accepts uppercase and mixed case" {
  @test.assert_eq(
    @hex.decode([b'D', b'E', b'a', b'D', b'b', b'E', b'E', b'F']),
    Some(([0xde, 0xad, 0xbe, 0xef] : FixedArray[Byte])),
  )
  // a full 16-char uppercase block exercises the SIMD path
  let upper : FixedArray[Byte] = [
    b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9', b'A', b'B', b'C',
    b'D', b'E', b'F',
  ]
  @test.assert_eq(
    @hex.decode(upper),
    Some(([0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef] : FixedArray[Byte])),
  )
}

///|
test "decode rejects bad input" {
  @test.assert_eq(@hex.decode([b'a']), None)
  @test.assert_eq(@hex.decode([b'a', b'g']), None)
  @test.assert_eq(@hex.decode([b' ', b'1']), None)
  // an invalid character at every position of a 32-char buffer, so both the
  // SIMD path and the scalar tail reject
  for pos in 0..<32 {
    let chars : FixedArray[Byte] = FixedArray::make(32, b'5')
    for
      bad in (
        [b'g', b'G', b'/', b':', b'@', b'`', 0x00, 0xff] : FixedArray[Byte]) {
      chars[pos] = bad
      @test.assert_eq(@hex.decode(chars), None)
    }
  }
}
