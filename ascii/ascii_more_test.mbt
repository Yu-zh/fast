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
fn upper_ref(bytes : FixedArray[Byte]) -> Unit {
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b >= b'a' && b <= b'z' {
      bytes[i] = b & 0xdf
    }
  }
}

///|
fn dup(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(bytes.length(), 0)
  for i in 0..<bytes.length() {
    out[i] = bytes[i]
  }
  out
}

///|
test "to_upper_ascii known and scalar cross-check" {
  let bytes : FixedArray[Byte] = [b'H', b'i', b'!', b'z']
  @ascii.to_upper_ascii(bytes)
  @test.assert_eq(bytes, [b'H', b'I', b'!', b'Z'])
  for len in [0, 1, 15, 16, 17, 33, 100] {
    let a : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      a[i] = ((i * 7 + 1) & 0xff).to_byte()
    }
    let b = dup(a)
    @ascii.to_upper_ascii(a)
    upper_ref(b)
    @test.assert_eq(a, b)
  }
}

///|
test "eq_ignore_case" {
  @test.assert_eq(@ascii.eq_ignore_case([b'H', b'i'], [b'h', b'I']), true)
  @test.assert_eq(@ascii.eq_ignore_case([b'a', b'b'], [b'a', b'c']), false)
  // differing lengths
  @test.assert_eq(@ascii.eq_ignore_case([b'a'], [b'a', b'b']), false)
  // non-letters must not fold: '[' (0x5b) and '{' (0x7b) differ by 0x20
  @test.assert_eq(@ascii.eq_ignore_case([b'['], [b'{']), false)
  // a 20-byte pair exercises the SIMD path and the scalar tail
  let lower : FixedArray[Byte] = [
    b'h', b'e', b'l', b'l', b'o', b'_', b'w', b'o', b'r', b'l', b'd', b'_', b'1',
    b'2', b'3', b'_', b'a', b'b', b'c', b'd',
  ]
  let upper : FixedArray[Byte] = [
    b'H', b'E', b'L', b'L', b'O', b'_', b'W', b'O', b'R', b'L', b'D', b'_', b'1',
    b'2', b'3', b'_', b'A', b'B', b'C', b'D',
  ]
  @test.assert_eq(@ascii.eq_ignore_case(lower, upper), true)
}
