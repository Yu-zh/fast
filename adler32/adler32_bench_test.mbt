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
fn bench_data() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = (state & 0xff).to_byte()
  }
  bytes
}

///|
fn adler_scalar_bench(data : FixedArray[Byte]) -> UInt {
  let mut s1 = 1U
  let mut s2 = 0U
  for i in 0..<data.length() {
    s1 = (s1 + data[i].to_uint()) % 65521U
    s2 = (s2 + s1) % 65521U
  }
  (s2 << 16) | s1
}

///|
test "bench adler32 simd 64k" (it : @bench.T) {
  let data = bench_data()
  it.bench(fn() { it.keep(@adler32.checksum(data)) })
}

///|
test "bench adler32 scalar 64k" (it : @bench.T) {
  let data = bench_data()
  it.bench(fn() { it.keep(adler_scalar_bench(data)) })
}
