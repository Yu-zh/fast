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
test "parse_uint64 basics" {
  @test.assert_eq(@atoi.parse_uint64(of(b"0")), Some(0UL))
  @test.assert_eq(@atoi.parse_uint64(of(b"7")), Some(7UL))
  @test.assert_eq(@atoi.parse_uint64(of(b"42")), Some(42UL))
  @test.assert_eq(@atoi.parse_uint64(of(b"007")), Some(7UL))
  @test.assert_eq(@atoi.parse_uint64(of(b"1234567")), Some(1234567UL))
  @test.assert_eq(@atoi.parse_uint64(of(b"12345678")), Some(12345678UL))
  @test.assert_eq(@atoi.parse_uint64(of(b"123456789")), Some(123456789UL))
  @test.assert_eq(
    @atoi.parse_uint64(of(b"1234567890123456")),
    Some(1234567890123456UL),
  )
  @test.assert_eq(
    @atoi.parse_uint64(of(b"18446744073709551615")),
    Some(18446744073709551615UL),
  )
}

///|
test "parse_uint64 rejects bad input" {
  @test.assert_eq(@atoi.parse_uint64(of(b"")), None)
  @test.assert_eq(@atoi.parse_uint64(of(b"12a45")), None)
  @test.assert_eq(@atoi.parse_uint64(of(b"-1")), None)
  @test.assert_eq(@atoi.parse_uint64(of(b" 12")), None)
  @test.assert_eq(@atoi.parse_uint64(of(b"12 ")), None)
  // 2^64 and a clearly-too-long value overflow
  @test.assert_eq(@atoi.parse_uint64(of(b"18446744073709551616")), None)
  @test.assert_eq(@atoi.parse_uint64(of(b"99999999999999999999")), None)
  @test.assert_eq(@atoi.parse_uint64(of(b"123456789012345678901234")), None)
}

///|
test "parse_int64 basics" {
  @test.assert_eq(@atoi.parse_int64(of(b"0")), Some(0L))
  @test.assert_eq(@atoi.parse_int64(of(b"42")), Some(42L))
  @test.assert_eq(@atoi.parse_int64(of(b"+42")), Some(42L))
  @test.assert_eq(@atoi.parse_int64(of(b"-42")), Some(-42L))
  @test.assert_eq(@atoi.parse_int64(of(b"-007")), Some(-7L))
  @test.assert_eq(
    @atoi.parse_int64(of(b"9223372036854775807")),
    Some(9223372036854775807L),
  )
  @test.assert_eq(
    @atoi.parse_int64(of(b"-9223372036854775808")),
    Some(-9223372036854775808L),
  )
}

///|
test "parse_int64 rejects bad input and out-of-range" {
  @test.assert_eq(@atoi.parse_int64(of(b"")), None)
  @test.assert_eq(@atoi.parse_int64(of(b"-")), None)
  @test.assert_eq(@atoi.parse_int64(of(b"+")), None)
  @test.assert_eq(@atoi.parse_int64(of(b"--1")), None)
  @test.assert_eq(@atoi.parse_int64(of(b"4x")), None)
  @test.assert_eq(@atoi.parse_int64(of(b"9223372036854775808")), None)
  @test.assert_eq(@atoi.parse_int64(of(b"-9223372036854775809")), None)
}

///|
/// Cross-check the SIMD path against straightforward scalar parsing for many
/// values that span the eight-digit block boundary.
test "parse_uint64 matches scalar parsing" {
  let mut state = 0x2545f4914f6cdd1dUL
  for _ in 0..<2000 {
    state = state ^ (state << 13)
    state = state ^ (state >> 7)
    state = state ^ (state << 17)
    // build a decimal string of a random width 1..19
    let width = 1 + (state % 19UL).to_int()
    let value = state % pow10(width)
    let text = to_digits(value, width)
    let expected = scalar_parse(text)
    @test.assert_eq(@atoi.parse_uint64(text), Some(expected))
  }
}

///|
fn pow10(n : Int) -> UInt64 {
  let mut p = 1UL
  for _ in 0..<n {
    p = p * 10UL
  }
  p
}

///|
fn to_digits(value : UInt64, width : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(width, b'0')
  let mut v = value
  for i = width - 1; i >= 0; i = i - 1 {
    out[i] = b'0' + (v % 10UL).to_byte()
    v = v / 10UL
  }
  out
}

///|
fn scalar_parse(bytes : FixedArray[Byte]) -> UInt64 {
  let mut acc = 0UL
  for i in 0..<bytes.length() {
    acc = acc * 10UL + (bytes[i] - b'0').to_uint64()
  }
  acc
}
