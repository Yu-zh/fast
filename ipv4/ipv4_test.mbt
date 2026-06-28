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
test "parse known addresses" {
  @test.assert_eq(@ipv4.parse(of(b"0.0.0.0")), Some(0U))
  @test.assert_eq(@ipv4.parse(of(b"192.168.1.1")), Some(0xC0A80101U))
  @test.assert_eq(@ipv4.parse(of(b"255.255.255.255")), Some(0xFFFFFFFFU))
  @test.assert_eq(@ipv4.parse(of(b"8.8.8.8")), Some(0x08080808U))
}

///|
test "parse rejects malformed input" {
  @test.assert_eq(@ipv4.parse(of(b"256.0.0.1")), None) // octet > 255
  @test.assert_eq(@ipv4.parse(of(b"1.2.3")), None) // too few octets
  @test.assert_eq(@ipv4.parse(of(b"1.2.3.4.5")), None) // too many octets
  @test.assert_eq(@ipv4.parse(of(b"01.2.3.4")), None) // leading zero
  @test.assert_eq(@ipv4.parse(of(b"1.2.3.")), None) // empty octet
  @test.assert_eq(@ipv4.parse(of(b"1.2.3.a")), None) // non-digit
  @test.assert_eq(@ipv4.parse(of(b"1234.1.1.1")), None) // 4-digit octet
}

///|
test "format known addresses" {
  @test.assert_eq(@ipv4.format(0U), of(b"0.0.0.0"))
  @test.assert_eq(@ipv4.format(0xC0A80101U), of(b"192.168.1.1"))
  @test.assert_eq(@ipv4.format(0xFFFFFFFFU), of(b"255.255.255.255"))
}

///|
test "format then parse round-trips" {
  let mut state = 0x12345678U
  for _ in 0..<2000 {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    @test.assert_eq(@ipv4.parse(@ipv4.format(state)), Some(state))
  }
}
