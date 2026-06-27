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
test "sort signed integers" {
  let values : FixedArray[Int] = [
    17, -3, 0, -2147483648, 42, 17, 5, -1, 2147483647, 0, -3, 9,
  ]
  @quicksort.sort_int(values.mut_view())
  @test.assert_eq(values, [
    -2147483648, -3, -3, -1, 0, 0, 5, 9, 17, 17, 42, 2147483647,
  ])
}

///|
test "sort unsigned integers" {
  let values : FixedArray[UInt] = [
    9U, 0xffffffffU, 3U, 0U, 7U, 3U, 0x80000000U, 1U, 0xffffffffU,
  ]
  @quicksort.sort_uint(values.mut_view())
  @test.assert_eq(values, [
    0U, 1U, 3U, 3U, 7U, 9U, 0x80000000U, 0xffffffffU, 0xffffffffU,
  ])
}

///|
test "sort already sorted and equal partitions" {
  let sorted : FixedArray[Int] = FixedArray::makei(128, i => i - 64)
  @quicksort.sort_int(sorted.mut_view())
  for index in 0..<sorted.length() {
    @test.assert_eq(sorted[index], index - 64)
  }
  let equal : FixedArray[Int] = FixedArray::make(128, 7)
  @quicksort.sort_int(equal.mut_view())
  for index in 0..<equal.length() {
    @test.assert_eq(equal[index], 7)
  }
}

///|
test "sort reverse and patterned data" {
  let values : FixedArray[Int] = FixedArray::make(257, 0)
  for index in 0..<values.length() {
    values[index] = 128 - index
  }
  for index in 0..<(values.length() / 5) {
    values[index * 5] = 13
  }
  @quicksort.sort_int(values.mut_view())
  for index in 1..<values.length() {
    assert_true(values[index - 1] <= values[index])
  }
}
