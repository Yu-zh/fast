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
let alphabet_ref : Bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
fn encode_scalar(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let out : FixedArray[Byte] = FixedArray::make((len + 2) / 3 * 4, 0)
  let mut i = 0
  let mut o = 0
  while i + 3 <= len {
    let n0 = bytes[i].to_int()
    let n1 = bytes[i + 1].to_int()
    let n2 = bytes[i + 2].to_int()
    out[o] = alphabet_ref[n0 >> 2]
    out[o + 1] = alphabet_ref[((n0 & 0x03) << 4) | (n1 >> 4)]
    out[o + 2] = alphabet_ref[((n1 & 0x0f) << 2) | (n2 >> 6)]
    out[o + 3] = alphabet_ref[n2 & 0x3f]
    i = i + 3
    o = o + 4
  }
  let rem = len - i
  if rem == 1 {
    let n0 = bytes[i].to_int()
    out[o] = alphabet_ref[n0 >> 2]
    out[o + 1] = alphabet_ref[(n0 & 0x03) << 4]
    out[o + 2] = b'='
    out[o + 3] = b'='
  } else if rem == 2 {
    let n0 = bytes[i].to_int()
    let n1 = bytes[i + 1].to_int()
    out[o] = alphabet_ref[n0 >> 2]
    out[o + 1] = alphabet_ref[((n0 & 0x03) << 4) | (n1 >> 4)]
    out[o + 2] = alphabet_ref[(n1 & 0x0f) << 2]
    out[o + 3] = b'='
  }
  out
}

///|
fn ascii(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  for i in 0..<s.length() {
    out[i] = s[i]
  }
  out
}

///|
test "encode known vectors" {
  @test.assert_eq(@base64.encode(ascii(b"")), ascii(b""))
  @test.assert_eq(@base64.encode(ascii(b"f")), ascii(b"Zg=="))
  @test.assert_eq(@base64.encode(ascii(b"fo")), ascii(b"Zm8="))
  @test.assert_eq(@base64.encode(ascii(b"foo")), ascii(b"Zm9v"))
  @test.assert_eq(@base64.encode(ascii(b"foob")), ascii(b"Zm9vYg=="))
  @test.assert_eq(@base64.encode(ascii(b"fooba")), ascii(b"Zm9vYmE="))
  @test.assert_eq(@base64.encode(ascii(b"foobar")), ascii(b"Zm9vYmFy"))
  @test.assert_eq(
    @base64.encode(ascii(b"Many hands make light work.")),
    ascii(b"TWFueSBoYW5kcyBtYWtlIGxpZ2h0IHdvcmsu"),
  )
}

///|
test "encode matches scalar for every length and byte pattern" {
  for len in [0, 1, 2, 3, 11, 12, 13, 15, 16, 17, 23, 24, 25, 48, 100, 257] {
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = ((i * 97 + 13) & 0xff).to_byte()
    }
    @test.assert_eq(@base64.encode(bytes), encode_scalar(bytes))
  }
}

///|
test "decode round-trips encode for all byte values" {
  for len in [0, 1, 2, 3, 11, 12, 13, 15, 16, 17, 23, 24, 25, 48, 100, 257] {
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = ((i * 251 + 7) & 0xff).to_byte()
    }
    @test.assert_eq(@base64.decode(@base64.encode(bytes)), Some(bytes))
  }
}

///|
test "decode covers the full byte range across a long buffer" {
  let bytes : FixedArray[Byte] = FixedArray::make(256, 0)
  for i in 0..<256 {
    bytes[i] = i.to_byte()
  }
  @test.assert_eq(@base64.decode(@base64.encode(bytes)), Some(bytes))
}

///|
test "decode accepts unpadded input" {
  @test.assert_eq(@base64.decode(ascii(b"Zg")), Some(ascii(b"f")))
  @test.assert_eq(@base64.decode(ascii(b"Zm8")), Some(ascii(b"fo")))
  @test.assert_eq(@base64.decode(ascii(b"Zm9v")), Some(ascii(b"foo")))
}

///|
test "decode rejects bad input" {
  // length ≡ 1 (mod 4) is impossible
  @test.assert_eq(@base64.decode(ascii(b"Z")), None)
  // characters outside the alphabet, in both the SIMD body and the tail
  @test.assert_eq(@base64.decode(ascii(b"Zm9v Zm9v")), None)
  @test.assert_eq(@base64.decode(ascii(b"Zm9*")), None)
  @test.assert_eq(@base64.decode(ascii(b"****************")), None)
  // misplaced padding in the middle
  @test.assert_eq(@base64.decode(ascii(b"Z=9v")), None)
  // an invalid byte injected at each position of a 16-char block
  for pos in 0..<16 {
    let chars = ascii(b"YWJjZGVmZ2hpamts")
    chars[pos] = b' '
    @test.assert_eq(@base64.decode(chars), None)
  }
}
