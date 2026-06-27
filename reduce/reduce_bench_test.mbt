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
  let mut state = 0x12345678
  for i in 0..<BENCH_LEN {
    state = state * 1103515245 + 12345
    values[i] = state >> 8
  }
  values
}

///|
fn sum_int_scalar(values : FixedArray[Int]) -> Int {
  let mut s = 0
  for i in 0..<values.length() {
    s = s + values[i]
  }
  s
}

///|
fn max_int_scalar(values : FixedArray[Int]) -> Int {
  let mut m = values[0]
  for i in 1..<values.length() {
    if values[i] > m {
      m = values[i]
    }
  }
  m
}

///|
test "bench sum_int simd 64k" (it : @bench.T) {
  let values = bench_ints()
  it.bench(fn() { it.keep(@reduce.sum_int(values)) })
}

///|
test "bench sum_int scalar 64k" (it : @bench.T) {
  let values = bench_ints()
  it.bench(fn() { it.keep(sum_int_scalar(values)) })
}

///|
test "bench max_int simd 64k" (it : @bench.T) {
  let values = bench_ints()
  it.bench(fn() { it.keep(@reduce.max_int(values)) })
}

///|
test "bench max_int scalar 64k" (it : @bench.T) {
  let values = bench_ints()
  it.bench(fn() { it.keep(max_int_scalar(values)) })
}
