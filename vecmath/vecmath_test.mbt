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
test "dot" {
  let a : FixedArray[Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
  let b : FixedArray[Double] = [10.0, 20.0, 30.0, 40.0, 50.0]
  // 10 + 40 + 90 + 160 + 250 = 550
  @test.assert_eq(@vecmath.dot(a, b), 550.0)
  @test.assert_eq(@vecmath.dot([], []), 0.0)
}

///|
test "axpy and scale" {
  let x : FixedArray[Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
  let y : FixedArray[Double] = [10.0, 10.0, 10.0, 10.0, 10.0]
  @vecmath.axpy(2.0, x, y)
  @test.assert_eq(y, [12.0, 14.0, 16.0, 18.0, 20.0])
  let z : FixedArray[Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
  @vecmath.scale(3.0, z)
  @test.assert_eq(z, [3.0, 6.0, 9.0, 12.0, 15.0])
}

///|
test "argmin and argmax" {
  @test.assert_eq(@vecmath.argmin([]), None)
  @test.assert_eq(@vecmath.argmax([]), None)
  let a : FixedArray[Double] = [3.5, -1.5, 2.0, -1.5, 9.0, -4.25, 0.0, 7.0]
  @test.assert_eq(@vecmath.argmin(a), Some(5))
  @test.assert_eq(@vecmath.argmax(a), Some(4))
  // first occurrence on ties
  let ties : FixedArray[Double] = [2.0, 1.0, 1.0, 2.0]
  @test.assert_eq(@vecmath.argmin(ties), Some(1))
  @test.assert_eq(@vecmath.argmax(ties), Some(0))
}

///|
test "dot and arg-reductions match scalar references" {
  for len in [0, 1, 2, 3, 7, 16, 17, 100] {
    let a : FixedArray[Double] = FixedArray::make(len, 0.0)
    let b : FixedArray[Double] = FixedArray::make(len, 0.0)
    let mut state = 0x2545f491
    for i in 0..<len {
      state = state * 1103515245 + 12345
      a[i] = ((state >> 8) % 1000).to_double()
      state = state * 1103515245 + 12345
      b[i] = ((state >> 8) % 1000).to_double()
    }
    // scalar dot (integer-valued, so exact regardless of summation order)
    let mut d = 0.0
    for i in 0..<len {
      d = d + a[i] * b[i]
    }
    @test.assert_eq(@vecmath.dot(a, b), d)
    if len > 0 {
      let mut lo = 0
      let mut hi = 0
      for i in 1..<len {
        if a[i] < a[lo] {
          lo = i
        }
        if a[i] > a[hi] {
          hi = i
        }
      }
      @test.assert_eq(@vecmath.argmin(a), Some(lo))
      @test.assert_eq(@vecmath.argmax(a), Some(hi))
    }
  }
}
