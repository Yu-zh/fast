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
fn scan_ref(values : FixedArray[Int]) -> FixedArray[Int] {
  let out : FixedArray[Int] = FixedArray::make(values.length(), 0)
  let mut acc = 0
  for i in 0..<values.length() {
    acc = acc + values[i]
    out[i] = acc
  }
  out
}

///|
test "scan_int known cases" {
  @test.assert_eq(@prefix_sum.scan_int([]), [])
  @test.assert_eq(@prefix_sum.scan_int([5]), [5])
  @test.assert_eq(@prefix_sum.scan_int([1, 2, 3, 4]), [1, 3, 6, 10])
  @test.assert_eq(@prefix_sum.scan_int([1, 2, 3, 4, 5, 6, 7]), [
    1, 3, 6, 10, 15, 21, 28,
  ])
  @test.assert_eq(@prefix_sum.scan_int([-1, 1, -1, 1, -1]), [-1, 0, -1, 0, -1])
}

///|
test "scan_int matches scalar across lengths" {
  for len in [0, 1, 3, 4, 5, 8, 15, 16, 17, 100, 257] {
    let values : FixedArray[Int] = FixedArray::make(len, 0)
    let mut state = 0x9e3779b9
    for i in 0..<len {
      state = state * 1103515245 + 12345
      values[i] = (state >> 16) % 1000
    }
    @test.assert_eq(@prefix_sum.scan_int(values), scan_ref(values))
  }
}
