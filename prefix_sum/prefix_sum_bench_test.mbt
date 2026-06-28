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
fn bench_ints() -> FixedArray[Int] {
  let values : FixedArray[Int] = FixedArray::make(BENCH_LEN, 0)
  for i in 0..<BENCH_LEN {
    values[i] = i % 7
  }
  values
}

///|
fn scan_scalar(values : FixedArray[Int]) -> FixedArray[Int] {
  let out : FixedArray[Int] = FixedArray::make(values.length(), 0)
  let mut acc = 0
  for i in 0..<values.length() {
    acc = acc + values[i]
    out[i] = acc
  }
  out
}

///|
test "bench scan_int simd 64k" (it : @bench.T) {
  let values = bench_ints()
  it.bench(fn() { it.keep(@prefix_sum.scan_int(values)) })
}

///|
test "bench scan_int scalar 64k" (it : @bench.T) {
  let values = bench_ints()
  it.bench(fn() { it.keep(scan_scalar(values)) })
}
