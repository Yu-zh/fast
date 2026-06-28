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
fn fill_f(n : Int, seed : UInt) -> FixedArray[Float] {
  let a : FixedArray[Float] = FixedArray::make(n, 0.0)
  let mut s = seed
  for i in 0..<n {
    s = s ^ (s << 13)
    s = s ^ (s >> 17)
    s = s ^ (s << 5)
    a[i] = Float::from_int((s % 200U).reinterpret_as_int() - 100) /
      (100.0 : Float)
  }
  a
}

///|
fn matmul_scalar(
  out : FixedArray[Float],
  x : FixedArray[Float],
  w : FixedArray[Float],
  n : Int,
  d : Int,
) -> Unit {
  for i in 0..<d {
    let mut s = (0.0 : Float)
    let base = i * n
    for j in 0..<n {
      s = s + w[base + j] * x[j]
    }
    out[i] = s
  }
}

///|
test "bench matmul simd 2000x288" (it : @bench.T) {
  let x = fill_f(288, 1)
  let w = fill_f(2000 * 288, 2)
  let out : FixedArray[Float] = FixedArray::make(2000, 0.0)
  it.bench(fn() { @infer.matmul(out, x, w, 288, 2000) })
}

///|
test "bench matmul scalar 2000x288" (it : @bench.T) {
  let x = fill_f(288, 1)
  let w = fill_f(2000 * 288, 2)
  let out : FixedArray[Float] = FixedArray::make(2000, 0.0)
  it.bench(fn() { matmul_scalar(out, x, w, 288, 2000) })
}
