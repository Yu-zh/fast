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
fn arr(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  for i in 0..<s.length() {
    out[i] = s[i]
  }
  out
}

///|
test "count_codepoints" {
  @test.assert_eq(@utf8.count_codepoints(arr(b"hello")), 5)
  // "Aé€" = A (1) + é (2 bytes) + € (3 bytes) = 3 codepoints
  let mixed : FixedArray[Byte] = [0x41, 0xC3, 0xA9, 0xE2, 0x82, 0xAC]
  @test.assert_eq(@utf8.count_codepoints(mixed), 3)
  @test.assert_eq(@utf8.count_codepoints(arr(b"")), 0)
  // long run that crosses the SIMD stride boundary
  let long : FixedArray[Byte] = FixedArray::make(40, 0)
  for i in 0..<40 {
    long[i] = if i % 2 == 0 { 0xC3 } else { 0xA9 } // 20 two-byte codepoints
  }
  @test.assert_eq(@utf8.count_codepoints(long), 20)
}

///|
test "latin1 to utf8 and back" {
  // every Latin-1 byte round-trips
  let latin1 : FixedArray[Byte] = FixedArray::make(256, 0)
  for i in 0..<256 {
    latin1[i] = i.to_byte()
  }
  let utf8 = @utf8.latin1_to_utf8(latin1)
  @test.assert_eq(@utf8.validate(utf8), true)
  @test.assert_eq(@utf8.utf8_to_latin1(utf8), Some(latin1))
  // known: 0xE9 ('é' in Latin-1) -> 0xC3 0xA9
  @test.assert_eq(@utf8.latin1_to_utf8([0x41, 0xE9]), [0x41, 0xC3, 0xA9])
}

///|
test "utf8_to_latin1 rejects out-of-range codepoints" {
  // '€' (U+20AC) is a 3-byte sequence, beyond Latin-1
  let euro : FixedArray[Byte] = [0xE2, 0x82, 0xAC]
  @test.assert_eq(@utf8.utf8_to_latin1(euro), None)
  // a 2-byte sequence above U+00FF (U+0100 = 0xC4 0x80)
  @test.assert_eq(@utf8.utf8_to_latin1([0xC4, 0x80]), None)
  // truncated sequence
  @test.assert_eq(@utf8.utf8_to_latin1([0xC3]), None)
}
