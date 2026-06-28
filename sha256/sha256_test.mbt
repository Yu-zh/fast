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
fn nibble(c : Byte) -> Int {
  if c >= b'0' && c <= b'9' {
    (c - b'0').to_int()
  } else {
    (c - b'a').to_int() + 10
  }
}

///|
fn hex_bytes(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length() / 2, 0)
  for i in 0..<out.length() {
    out[i] = ((nibble(s[i * 2]) << 4) | nibble(s[i * 2 + 1])).to_byte()
  }
  out
}

///|
test "sha256 NIST vectors" {
  @test.assert_eq(
    @sha256.hash(of(b"")),
    hex_bytes(
      b"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    ),
  )
  @test.assert_eq(
    @sha256.hash(of(b"abc")),
    hex_bytes(
      b"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
    ),
  )
  // 56-byte two-block message
  @test.assert_eq(
    @sha256.hash(
      of(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    ),
    hex_bytes(
      b"248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
    ),
  )
  @test.assert_eq(
    @sha256.hash(of(b"The quick brown fox jumps over the lazy dog")),
    hex_bytes(
      b"d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592",
    ),
  )
}

///|
test "sha256 handles block-boundary lengths" {
  // lengths around 55/56/63/64 exercise the padding edge cases
  for len in [55, 56, 57, 63, 64, 65, 119, 128] {
    let data : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      data[i] = ((i * 7 + 1) & 0xff).to_byte()
    }
    // digest is always 32 bytes; just check the length and determinism here
    let d1 = @sha256.hash(data)
    let d2 = @sha256.hash(data)
    @test.assert_eq(d1.length(), 32)
    @test.assert_eq(d1, d2)
  }
}
