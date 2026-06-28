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
test "encode known vectors (RFC 4648)" {
  @test.assert_eq(@base32.encode(of(b"")), of(b""))
  @test.assert_eq(@base32.encode(of(b"f")), of(b"MY======"))
  @test.assert_eq(@base32.encode(of(b"fo")), of(b"MZXQ===="))
  @test.assert_eq(@base32.encode(of(b"foo")), of(b"MZXW6==="))
  @test.assert_eq(@base32.encode(of(b"foob")), of(b"MZXW6YQ="))
  @test.assert_eq(@base32.encode(of(b"fooba")), of(b"MZXW6YTB"))
  @test.assert_eq(@base32.encode(of(b"foobar")), of(b"MZXW6YTBOI======"))
}

///|
test "decode known vectors" {
  @test.assert_eq(@base32.decode(of(b"MY======")), Some(of(b"f")))
  @test.assert_eq(@base32.decode(of(b"MZXW6YTBOI======")), Some(of(b"foobar")))
  // unpadded also accepted
  @test.assert_eq(@base32.decode(of(b"MZXW6YTB")), Some(of(b"fooba")))
}

///|
test "decode rejects bad input" {
  @test.assert_eq(@base32.decode(of(b"MZX")), None) // 3 chars is an invalid group length
  @test.assert_eq(@base32.decode(of(b"1ZXW6YTB")), None) // '1' not in alphabet
  @test.assert_eq(@base32.decode(of(b"mzxw6ytb")), None) // lowercase not accepted
  @test.assert_eq(@base32.decode(of(b"AAAAAAAA AAAAAAAA")), None) // space
}

///|
test "decode round-trips encode for all byte values" {
  for len in [0, 1, 2, 3, 4, 5, 6, 10, 11, 16, 17, 100, 257] {
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = ((i * 131 + 7) & 0xff).to_byte()
    }
    @test.assert_eq(@base32.decode(@base32.encode(bytes)), Some(bytes))
  }
}

///|
test "decode covers the full byte range" {
  let bytes : FixedArray[Byte] = FixedArray::make(256, 0)
  for i in 0..<256 {
    bytes[i] = i.to_byte()
  }
  @test.assert_eq(@base32.decode(@base32.encode(bytes)), Some(bytes))
}
