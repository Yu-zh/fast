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
test "base64url maps + and / and drops padding" {
  // 0xff bytes encode to all-63 sextets ('/' in standard, '_' url-safe)
  let threes : FixedArray[Byte] = [0xff, 0xff, 0xff]
  @test.assert_eq(@base64.encode_url(threes), [b'_', b'_', b'_', b'_'])
  // a value producing '+' (sextet 62) becomes '-'
  let plus : FixedArray[Byte] = [0xfb, 0xf0, 0x00]
  @test.assert_eq(@base64.encode_url(plus)[0], b'-')
  // padding is dropped
  @test.assert_eq(@base64.encode_url([b'f']), [b'Z', b'g'])
}

///|
test "base64url round-trips" {
  for len in [0, 1, 2, 3, 11, 16, 17, 48, 100] {
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = ((i * 191 + 17) & 0xff).to_byte()
    }
    @test.assert_eq(@base64.decode_url(@base64.encode_url(bytes)), Some(bytes))
  }
}
