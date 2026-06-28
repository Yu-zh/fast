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
fn scalar_u64_bench(value : UInt64) -> FixedArray[Byte] {
  if value == 0UL {
    return [b'0']
  }
  let tmp : FixedArray[Byte] = FixedArray::make(20, 0)
  let mut v = value
  let mut k = 0
  while v > 0UL {
    tmp[k] = b'0' + (v % 10UL).to_byte()
    v = v / 10UL
    k = k + 1
  }
  let out : FixedArray[Byte] = FixedArray::make(k, 0)
  for j in 0..<k {
    out[j] = tmp[k - 1 - j]
  }
  out
}

///|
test "bench format_uint64 simd 16-digit" (it : @bench.T) {
  it.bench(fn() { it.keep(@itoa.format_uint64(1234567890123456UL)) })
}

///|
test "bench format_uint64 scalar 16-digit" (it : @bench.T) {
  it.bench(fn() { it.keep(scalar_u64_bench(1234567890123456UL)) })
}
