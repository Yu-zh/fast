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
test "a /24 network matches its host range" {
  let net = @cidr.parse(of(b"192.168.1.0/24")).unwrap()
  @test.assert_eq(net.contains_bytes(of(b"192.168.1.0")), true)
  @test.assert_eq(net.contains_bytes(of(b"192.168.1.5")), true)
  @test.assert_eq(net.contains_bytes(of(b"192.168.1.255")), true)
  @test.assert_eq(net.contains_bytes(of(b"192.168.2.1")), false)
  @test.assert_eq(net.contains_bytes(of(b"10.0.0.1")), false)
}

///|
test "a bare address is a /32 host route" {
  let net = @cidr.parse(of(b"10.0.0.7")).unwrap()
  @test.assert_eq(net.contains_bytes(of(b"10.0.0.7")), true)
  @test.assert_eq(net.contains_bytes(of(b"10.0.0.8")), false)
}

///|
test "malformed networks and prefixes are rejected" {
  @test.assert_eq(@cidr.parse(of(b"192.168.1.0/33")) is None, true)
  @test.assert_eq(@cidr.parse(of(b"999.0.0.0/8")) is None, true)
  @test.assert_eq(@cidr.parse(of(b"192.168.1.0/")) is None, true)
}

///|
test "an allowlist matches across several networks" {
  let allow = @cidr.Allowlist::of([
    of(b"10.0.0.0/8"),
    of(b"192.168.0.0/16"),
    of(b"172.16.5.4/32"),
  ]).unwrap()
  @test.assert_eq(allow.allows_bytes(of(b"10.255.255.255")), true)
  @test.assert_eq(allow.allows_bytes(of(b"192.168.50.50")), true)
  @test.assert_eq(allow.allows_bytes(of(b"172.16.5.4")), true)
  @test.assert_eq(allow.allows_bytes(of(b"172.16.5.5")), false)
  @test.assert_eq(allow.allows_bytes(of(b"8.8.8.8")), false)
}
