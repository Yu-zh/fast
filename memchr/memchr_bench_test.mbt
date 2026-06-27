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
/// 64 KiB of printable noise with the needle only at the very end, so both
/// implementations scan the whole buffer.
fn bench_haystack() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = (0x20U + (state & 0x3f)).to_byte()
  }
  bytes[BENCH_LEN - 1] = 0x00
  bytes
}

///|
test "bench find_byte simd 64k" (it : @bench.T) {
  let haystack = bench_haystack()
  it.bench(fn() { it.keep(@memchr.find_byte(haystack, 0x00)) })
}

///|
test "bench find_byte scalar 64k" (it : @bench.T) {
  let haystack = bench_haystack()
  it.bench(fn() { it.keep(find_byte_scalar(haystack, 0x00)) })
}

///|
test "bench count_byte simd 64k" (it : @bench.T) {
  let haystack = bench_haystack()
  it.bench(fn() { it.keep(@memchr.count_byte(haystack, b' ')) })
}

///|
test "bench count_byte scalar 64k" (it : @bench.T) {
  let haystack = bench_haystack()
  it.bench(fn() { it.keep(count_byte_scalar(haystack, b' ')) })
}
