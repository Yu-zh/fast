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
fn i8s(vals : Array[Int]) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(vals.length(), 0)
  for i in 0..<vals.length() {
    out[i] = (vals[i] & 0xff).to_byte()
  }
  out
}

///|
fn signed(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 128 {
    v - 256
  } else {
    v
  }
}

///|
fn gemm_scalar(
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
        s = s + signed(a[i * k + t]) * signed(bt[j * k + t])
      }
      c[i * n + j] = s
    }
  }
  c
}

///|
test "gemm_i8 known result" {
  let a = i8s([1, 2, 3, 4, 5, 6]) // 2x3
  let bt = i8s([1, 0, 0, 0, 1, 1]) // 2x3 (B transposed), n=2
  @test.assert_eq(@gemm.gemm_i8(a, bt, 2, 3, 2), [1, 5, 4, 11])
}

///|
test "gemm_i8 with negatives" {
  let a = i8s([-1, 2, -3]) // 1x3
  let bt = i8s([4, -5, 6]) // 1x3, n=1
  // (-1)(4) + (2)(-5) + (-3)(6) = -4 - 10 - 18 = -32
  @test.assert_eq(@gemm.gemm_i8(a, bt, 1, 3, 1), [-32])
}

///|
test "relu_i32 and argmax_i32" {
  let x : FixedArray[Int] = [-1, 0, 5, -3, 2]
  @gemm.relu_i32(x)
  @test.assert_eq(x, [0, 0, 5, 0, 2])
  @test.assert_eq(@gemm.argmax_i32([3, 1, 9, 9, 2]), Some(2))
  @test.assert_eq(@gemm.argmax_i32([-5, -1, -9]), Some(1))
  @test.assert_eq(@gemm.argmax_i32([]), None)
}

///|
test "gemm_i8 matches scalar over random int8 matrices" {
  let dims = [(1, 16, 1), (2, 3, 2), (4, 20, 5), (8, 33, 3), (3, 64, 7)]
  let mut state = 0x2545f491
  for dim in dims {
    let (m, k, n) = dim
    let a : FixedArray[Byte] = FixedArray::make(m * k, 0)
    let bt : FixedArray[Byte] = FixedArray::make(n * k, 0)
    for i in 0..<a.length() {
      state = state * 1103515245 + 12345
      a[i] = ((state >> 16) & 0xff).to_byte()
    }
    for i in 0..<bt.length() {
      state = state * 1103515245 + 12345
      bt[i] = ((state >> 16) & 0xff).to_byte()
    }
    @test.assert_eq(@gemm.gemm_i8(a, bt, m, k, n), gemm_scalar(a, bt, m, k, n))
  }
}

///|
test "two-layer forward pass composes" {
  // input (1x4) -> layer1 weights (3x4) -> relu -> layer2 (2x3) -> argmax
  let input = i8s([10, -5, 3, 7]) // 1x4
  let w1 = i8s([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]) // 3x4 transposed
  let h = @gemm.gemm_i8(input, w1, 1, 4, 3) // -> [10, -5, 3]
  @gemm.relu_i32(h) // can't mutate FixedArray[Int]? it is mutable
  @test.assert_eq(h, [10, 0, 3])
  let w2 = i8s([1, 1, 1, 2, 0, 0]) // 2x3 transposed
  // logits = [10+0+3, 20+0+0] = [13, 20]
  // need w2 as bytes contiguous per output row; gemm reads h as int... but h is
  // int32, gemm_i8 expects int8 bytes — so quantize h back to bytes for layer 2
  let hq = i8s([h[0], h[1], h[2]])
  let logits = @gemm.gemm_i8(hq, w2, 1, 3, 2)
  @test.assert_eq(logits, [13, 20])
  @test.assert_eq(@gemm.argmax_i32(logits), Some(1))
}
