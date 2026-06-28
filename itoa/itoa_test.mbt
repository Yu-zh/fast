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
fn scalar_u64(value : UInt64) -> FixedArray[Byte] {
  if value == 0UL {
    return [b'0']
  }
  let tmp : FixedArray[Byte] = FixedArray::make(20, 0)
  let mut v = value
  let mut k = 0
  while v > 0UL {
    tmp[k] = b'0' + (v % 10UL).to_byte()
    v = v / 10UL
    k = k + 1
  }
  let out : FixedArray[Byte] = FixedArray::make(k, 0)
  for j in 0..<k {
    out[j] = tmp[k - 1 - j]
  }
  out
}

///|
test "format_uint64 known values" {
  @test.assert_eq(@itoa.format_uint64(0UL), arr(b"0"))
  @test.assert_eq(@itoa.format_uint64(7UL), arr(b"7"))
  @test.assert_eq(@itoa.format_uint64(42UL), arr(b"42"))
  @test.assert_eq(@itoa.format_uint64(100000000UL), arr(b"100000000"))
  @test.assert_eq(@itoa.format_uint64(12345678UL), arr(b"12345678"))
  @test.assert_eq(
    @itoa.format_uint64(18446744073709551615UL),
    arr(b"18446744073709551615"),
  )
}

///|
test "format_int64 and format_int" {
  @test.assert_eq(@itoa.format_int64(0L), arr(b"0"))
  @test.assert_eq(@itoa.format_int64(-1L), arr(b"-1"))
  @test.assert_eq(@itoa.format_int64(-42L), arr(b"-42"))
  @test.assert_eq(
    @itoa.format_int64(9223372036854775807L),
    arr(b"9223372036854775807"),
  )
  @test.assert_eq(
    @itoa.format_int64(-9223372036854775808L),
    arr(b"-9223372036854775808"),
  )
  @test.assert_eq(@itoa.format_int(-12345), arr(b"-12345"))
}

///|
test "format_uint64 matches scalar over many values" {
  let mut state = 0x9e3779b97f4a7c15UL
  for _ in 0..<3000 {
    state = state ^ (state << 13)
    state = state ^ (state >> 7)
    state = state ^ (state << 17)
    @test.assert_eq(@itoa.format_uint64(state), scalar_u64(state))
    // also exercise small / boundary-width values
    let small = state % 1000000000UL
    @test.assert_eq(@itoa.format_uint64(small), scalar_u64(small))
  }
}

///|
test "round-trips through atoi-style scalar parse" {
  for
    v in [0UL, 9UL, 10UL, 99UL, 100UL, 9999UL, 10000UL, 99999999UL, 100000000UL] {
    let s = @itoa.format_uint64(v)
    let mut parsed = 0UL
    for i in 0..<s.length() {
      parsed = parsed * 10UL + (s[i] - b'0').to_uint64()
    }
    @test.assert_eq(parsed, v)
  }
}
