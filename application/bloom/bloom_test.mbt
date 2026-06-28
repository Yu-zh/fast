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
test "no false negatives for inserted keys" {
  let f = @bloom.Bloom::new(4096, 5)
  let keys = [b"apple", b"banana", b"cherry", b"date", b"elderberry"]
  for k in keys {
    f.add(of(k))
  }
  for k in keys {
    @test.assert_eq(f.contains(of(k)), true)
  }
}

///|
test "absent keys are rejected with adequate sizing" {
  let f = @bloom.Bloom::new(8192, 6)
  for i in 0..<200 {
    let key : FixedArray[Byte] = [b'k', b'e', b'y', i.to_byte()]
    f.add(key)
  }
  @test.assert_eq(f.contains(of(b"definitely-not-present-xyz")), false)
}

///|
test "distinct content gives distinct membership" {
  let f = @bloom.Bloom::new(1024, 4)
  f.add(of(b"hello"))
  @test.assert_eq(f.contains(of(b"hello")), true)
  @test.assert_eq(f.contains(of(b"world")), false)
}
