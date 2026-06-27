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
fn scalar_parse_uint64(bytes : FixedArray[Byte]) -> UInt64? {
  let len = bytes.length()
  if len == 0 {
    return None
  }
  let mut acc = 0UL
  for i in 0..<len {
    let b = bytes[i]
    if b < b'0' || b > b'9' {
      return None
    }
    acc = acc * 10UL + (b - b'0').to_uint64()
  }
  Some(acc)
}

///|
test "bench parse_uint64 simd 16-digit" (it : @bench.T) {
  let value = of(b"1234567890123456")
  it.bench(fn() { it.keep(@atoi.parse_uint64(value)) })
}

///|
test "bench parse_uint64 scalar 16-digit" (it : @bench.T) {
  let value = of(b"1234567890123456")
  it.bench(fn() { it.keep(scalar_parse_uint64(value)) })
}
