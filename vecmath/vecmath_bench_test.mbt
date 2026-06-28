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
const N = 8192

///|
fn ramp() -> FixedArray[Double] {
  let a : FixedArray[Double] = FixedArray::make(N, 0.0)
  for i in 0..<N {
    a[i] = (i % 1000).to_double()
  }
  a
}

///|
fn dot_scalar(a : FixedArray[Double], b : FixedArray[Double]) -> Double {
  let mut s = 0.0
  for i in 0..<a.length() {
    s = s + a[i] * b[i]
  }
  s
}

///|
test "bench dot simd 8k" (it : @bench.T) {
  let a = ramp()
  let b = ramp()
  it.bench(fn() { it.keep(@vecmath.dot(a, b)) })
}

///|
test "bench dot scalar 8k" (it : @bench.T) {
  let a = ramp()
  let b = ramp()
  it.bench(fn() { it.keep(dot_scalar(a, b)) })
}
