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
const BENCH_LEN = 65536

///|
fn bench_haystack() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x12345678U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    // a 16-letter alphabet: needle bytes are common, so probes fire often
    bytes[i] = b'a' + (state & 0x0f).to_byte()
  }
  // hide the needle near the end
  let needle = b"needle_marker_42"
  for k in 0..<needle.length() {
    bytes[BENCH_LEN - 100 + k] = needle[k]
  }
  bytes
}

///|
fn find_scalar_bench(
  haystack : FixedArray[Byte],
  needle : FixedArray[Byte],
) -> Int? {
  let n = haystack.length()
  let m = needle.length()
  for i in 0..<=(n - m) {
    let mut ok = true
    for k in 0..<m {
      if haystack[i + k] != needle[k] {
        ok = false
        break
      }
    }
    if ok {
      return Some(i)
    }
  }
  None
}

///|
test "bench find simd 64k" (it : @bench.T) {
  let haystack = bench_haystack()
  let needle : FixedArray[Byte] = FixedArray::make(16, 0)
  let marker = b"needle_marker_42"
  for k in 0..<16 {
    needle[k] = marker[k]
  }
  it.bench(fn() { it.keep(@memmem.find(haystack, needle)) })
}

///|
test "bench find scalar 64k" (it : @bench.T) {
  let haystack = bench_haystack()
  let needle : FixedArray[Byte] = FixedArray::make(16, 0)
  let marker = b"needle_marker_42"
  for k in 0..<16 {
    needle[k] = marker[k]
  }
  it.bench(fn() { it.keep(find_scalar_bench(haystack, needle)) })
}
