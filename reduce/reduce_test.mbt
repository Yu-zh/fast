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
fn sum_int_ref(values : FixedArray[Int]) -> Int {
  let mut s = 0
  for i in 0..<values.length() {
    s = s + values[i]
  }
  s
}

///|
test "sum_int basics and tails" {
  @test.assert_eq(@reduce.sum_int([]), 0)
  @test.assert_eq(@reduce.sum_int([5]), 5)
  @test.assert_eq(@reduce.sum_int([1, 2, 3, 4]), 10)
  @test.assert_eq(@reduce.sum_int([1, 2, 3, 4, 5, 6, 7]), 28)
  @test.assert_eq(@reduce.sum_int([-1, -2, -3, -4, -5]), -15)
}

///|
test "min_int / max_int" {
  @test.assert_eq(@reduce.min_int([]), None)
  @test.assert_eq(@reduce.max_int([]), None)
  @test.assert_eq(@reduce.min_int([3]), Some(3))
  @test.assert_eq(@reduce.min_int([5, -1, 3, -1, 0, 9, -7, 2]), Some(-7))
  @test.assert_eq(@reduce.max_int([5, -1, 3, -1, 0, 9, -7, 2]), Some(9))
  @test.assert_eq(@reduce.max_int([5, -1, 3, 8, 0, 9, -7]), Some(9))
}

///|
test "is_sorted_int" {
  @test.assert_eq(@reduce.is_sorted_int([]), true)
  @test.assert_eq(@reduce.is_sorted_int([1]), true)
  @test.assert_eq(@reduce.is_sorted_int([1, 2, 2, 3, 4, 5, 6, 7, 8, 9]), true)
  @test.assert_eq(@reduce.is_sorted_int([1, 2, 3, 4, 5, 6, 7, 9, 8]), false)
  @test.assert_eq(@reduce.is_sorted_int([2, 1]), false)
  @test.assert_eq(@reduce.is_sorted_int([-5, -3, -3, 0, 1, 100]), true)
}

///|
test "double reductions" {
  @test.assert_eq(@reduce.sum_double([]), 0.0)
  @test.assert_eq(@reduce.sum_double([1.0, 2.0, 3.0, 4.0, 5.0]), 15.0)
  @test.assert_eq(@reduce.min_double([]), None)
  @test.assert_eq(@reduce.min_double([3.5, -1.5, 2.0, 9.0, -4.25]), Some(-4.25))
  @test.assert_eq(@reduce.max_double([3.5, -1.5, 2.0, 9.0, -4.25]), Some(9.0))
}

///|
test "sum_int matches scalar over pseudo-random data of every length" {
  for len in [0, 1, 3, 4, 5, 8, 15, 16, 17, 100, 257] {
    let values : FixedArray[Int] = FixedArray::make(len, 0)
    let mut state = 0x9e3779b9
    for i in 0..<len {
      state = state * 1103515245 + 12345
      values[i] = state >> 8
    }
    @test.assert_eq(@reduce.sum_int(values), sum_int_ref(values))
    // min and max agree with a scalar scan too
    if len > 0 {
      let mut lo = values[0]
      let mut hi = values[0]
      for i in 1..<len {
        if values[i] < lo {
          lo = values[i]
        }
        if values[i] > hi {
          hi = values[i]
        }
      }
      @test.assert_eq(@reduce.min_int(values), Some(lo))
      @test.assert_eq(@reduce.max_int(values), Some(hi))
    }
  }
}
