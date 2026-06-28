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
const M = 64

///|
const K = 256

///|
const N = 64

///|
fn fill(n : Int, seed : UInt) -> FixedArray[Byte] {
  let a : FixedArray[Byte] = FixedArray::make(n, 0)
  let mut state = seed
  for i in 0..<n {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    a[i] = (state & 0xff).to_byte()
  }
  a
}

///|
fn signed_b(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 128 {
    v - 256
  } else {
    v
  }
}

///|
fn gemm_scalar_bench(
  a : FixedArray[Byte],
  bt : FixedArray[Byte],
  m : Int,
  k : Int,
  n : Int,
) -> FixedArray[Int] {
  let c : FixedArray[Int] = FixedArray::make(m * n, 0)
  for i in 0..<m {
    for j in 0..<n {
      let mut s = 0
      for t in 0..<k {
        s = s + signed_b(a[i * k + t]) * signed_b(bt[j * k + t])
      }
      c[i * n + j] = s
    }
  }
  c
}

///|
test "bench gemm_i8 simd 64x256x64" (it : @bench.T) {
  let a = fill(M * K, 1)
  let bt = fill(N * K, 2)
  it.bench(fn() { it.keep(@gemm.gemm_i8(a, bt, M, K, N)) })
}

///|
test "bench gemm_i8 scalar 64x256x64" (it : @bench.T) {
  let a = fill(M * K, 1)
  let bt = fill(N * K, 2)
  it.bench(fn() { it.keep(gemm_scalar_bench(a, bt, M, K, N)) })
}
