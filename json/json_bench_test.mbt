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
/// Roughly 64 KiB of realistic JSON: an array of repeated objects.
fn bench_doc() -> FixedArray[Byte] {
  let item = b"{\"id\": 123456, \"name\": \"item \\\"123\\\"\", \"price\": -1.25e3, \"active\": true, \"tags\": [\"alpha\", \"beta\"], \"note\": null}"
  let count = 65536 / (item.length() + 1)
  let total = 1 + count * (item.length() + 1)
  let bytes : FixedArray[Byte] = FixedArray::make(total, b',')
  bytes[0] = b'['
  let mut pos = 1
  for _ in 0..<count {
    for j in 0..<item.length() {
      bytes[pos + j] = item[j]
    }
    pos = pos + item.length() + 1
  }
  bytes[total - 1] = b']'
  bytes
}

///|
test "bench structural_indices simd 64k" (it : @bench.T) {
  let doc = bench_doc()
  it.bench(fn() { it.keep(@json.structural_indices(doc)) })
}

///|
test "bench structural_indices scalar 64k" (it : @bench.T) {
  let doc = bench_doc()
  it.bench(fn() { it.keep(reference(doc)) })
}

///|
fn bench_doc_string() -> String {
  let doc = bench_doc()
  let buf = StringBuilder::new()
  for i in 0..<doc.length() {
    buf.write_char(doc[i].to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
test "bench parse fast 64k" (it : @bench.T) {
  let doc = bench_doc()
  it.bench(fn() { it.keep(try! @json.parse(doc)) })
}

///|
test "bench parse core 64k" (it : @bench.T) {
  let doc = bench_doc_string()
  it.bench(fn() { it.keep(try! @corejson.parse(doc)) })
}

///|
/// End-to-end comparison when the document arrives as UTF-8 bytes: core
/// needs the bytes decoded into a UTF-16 String first (ASCII-only decode
/// here, which flatters it), while @json.parse consumes bytes directly.
test "bench parse core from bytes 64k" (it : @bench.T) {
  let doc = bench_doc()
  it.bench(fn() {
    let buf = StringBuilder::new()
    for i in 0..<doc.length() {
      buf.write_char(doc[i].to_int().unsafe_to_char())
    }
    it.keep(try! @corejson.parse(buf.to_string()))
  })
}
