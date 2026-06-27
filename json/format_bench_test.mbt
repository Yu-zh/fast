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
/// A ~64 KiB pretty-printed document with whitespace between every token.
fn bench_pretty() -> FixedArray[Byte] {
  let item = b"{\n  \"id\": 123456,\n  \"name\": \"item\",\n  \"price\": -1.25e3,\n  \"ok\": true\n},\n"
  let count = 65536 / item.length()
  let total = 2 + count * item.length()
  let bytes : FixedArray[Byte] = FixedArray::make(total, b' ')
  bytes[0] = b'['
  let mut pos = 1
  for _ in 0..<count {
    for j in 0..<item.length() {
      bytes[pos + j] = item[j]
    }
    pos = pos + item.length()
  }
  bytes[total - 1] = b']'
  bytes
}

///|
test "bench minify simd 64k" (it : @bench.T) {
  let doc = bench_pretty()
  it.bench(fn() { it.keep(@json.minify(doc)) })
}

///|
test "bench escape_string simd 64k" (it : @bench.T) {
  let doc = bench_pretty()
  it.bench(fn() { it.keep(@json.escape_string(doc)) })
}
