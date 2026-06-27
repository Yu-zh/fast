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
/// Roughly 64 KiB of CSV: repeated rows with some quoted fields.
fn bench_doc() -> FixedArray[Byte] {
  let row = b"12345,\"a quoted, value\",hello world,\"x\"\"y\",678\n"
  let reps = 65536 / row.length()
  let total = row.length() * reps
  let doc : FixedArray[Byte] = FixedArray::make(total, 0)
  let mut pos = 0
  for _ in 0..<reps {
    for j in 0..<row.length() {
      doc[pos + j] = row[j]
    }
    pos = pos + row.length()
  }
  doc
}

///|
fn positions_scalar(bytes : FixedArray[Byte], delim : Byte) -> Array[Int]? {
  let out = []
  let mut in_quote = false
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b == b'"' {
      in_quote = !in_quote
    } else if !in_quote && (b == delim || b == b'\n') {
      out.push(i)
    }
  }
  if in_quote {
    return None
  }
  Some(out)
}

///|
test "bench unquoted_positions simd 64k" (it : @bench.T) {
  let doc = bench_doc()
  it.bench(fn() { it.keep(@csv.unquoted_positions(doc)) })
}

///|
test "bench unquoted_positions scalar 64k" (it : @bench.T) {
  let doc = bench_doc()
  it.bench(fn() { it.keep(positions_scalar(doc, b',')) })
}
