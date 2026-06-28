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
test "charset contains and validate" {
  let cs = @charset.Charset::of(of(b"0123456789abcdef"))
  @test.assert_eq(cs.contains(b'a'), true)
  @test.assert_eq(cs.contains(b'f'), true)
  @test.assert_eq(cs.contains(b'g'), false)
  @test.assert_eq(cs.contains(b'A'), false)
  @test.assert_eq(cs.validate(of(b"deadbeef0123")), true)
  @test.assert_eq(cs.validate(of(b"deadbeefXYZ")), false)
  @test.assert_eq(cs.find_invalid(of(b"abcdefg0")), Some(6))
  @test.assert_eq(cs.find_invalid(of(b"abcdef")), None)
}

///|
test "charset matches a scalar membership set over the full byte range" {
  // an arbitrary set: vowels, digits, and a few punctuation bytes
  let allowed = of(b"aeiouAEIOU0123456789-_.~ ")
  let cs = @charset.Charset::of(allowed)
  // reference membership table
  let present : FixedArray[Bool] = FixedArray::make(256, false)
  for i in 0..<allowed.length() {
    present[allowed[i].to_int()] = true
  }
  // every byte value classified correctly
  for v in 0..<256 {
    @test.assert_eq(cs.contains(v.to_byte()), present[v])
  }
  // find_invalid agrees with a scalar scan over a long pseudo-random buffer
  let n = 200
  let buf : FixedArray[Byte] = FixedArray::make(n, 0)
  for i in 0..<n {
    buf[i] = ((i * 53 + 7) & 0xff).to_byte()
  }
  let mut expected = -1
  for i in 0..<n {
    if !present[buf[i].to_int()] {
      expected = i
      break
    }
  }
  let got = match cs.find_invalid(buf) {
    Some(idx) => idx
    None => -1
  }
  @test.assert_eq(got, expected)
}
