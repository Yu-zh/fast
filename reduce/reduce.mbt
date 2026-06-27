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

// Vectorized reductions over numeric arrays. Like `quicksort`, lanes are
// gathered with `i32x4_const` / `f64x2_const` (there is no vector load for
// typed arrays); the win is in the vectorized arithmetic and comparisons,
// with a horizontal combine and scalar tail at the end. Floating-point sums
// are lane-partitioned, so results can differ from a strict left-to-right
// scalar sum by rounding.

///|
fn imin(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn imax(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn load4(values : FixedArray[Int], i : Int) -> V128 {
  @v128.i32x4_const(
    values[i].reinterpret_as_uint(),
    values[i + 1].reinterpret_as_uint(),
    values[i + 2].reinterpret_as_uint(),
    values[i + 3].reinterpret_as_uint(),
  )
}

///|
fn lane_int(v : V128, lane : Int) -> Int {
  @v128.i32x4_extract_lane(v, lane).reinterpret_as_int()
}

///|
/// Returns the sum of all elements, wrapping on 32-bit overflow (matching a
/// scalar `+` accumulation).
pub fn sum_int(values : FixedArray[Int]) -> Int {
  let len = values.length()
  let mut acc = @v128.i32x4_splat(0)
  let mut i = 0
  while i + 4 <= len {
    acc = @v128.i32x4_add(acc, load4(values, i))
    i = i + 4
  }
  let mut total = lane_int(acc, 0) +
    lane_int(acc, 1) +
    (lane_int(acc, 2) + lane_int(acc, 3))
  while i < len {
    total = total + values[i]
    i = i + 1
  }
  total
}

///|
/// Returns the minimum element, or `None` when the array is empty.
pub fn min_int(values : FixedArray[Int]) -> Int? {
  let len = values.length()
  if len == 0 {
    return None
  }
  let mut i = 0
  let mut vacc = @v128.i32x4_splat(0)
  let mut seeded = false
  while i + 4 <= len {
    let v = load4(values, i)
    vacc = if seeded { @v128.i32x4_min_s(vacc, v) } else { v }
    seeded = true
    i = i + 4
  }
  let mut result = if seeded {
    imin(
      imin(lane_int(vacc, 0), lane_int(vacc, 1)),
      imin(lane_int(vacc, 2), lane_int(vacc, 3)),
    )
  } else {
    values[0]
  }
  while i < len {
    result = imin(result, values[i])
    i = i + 1
  }
  Some(result)
}

///|
/// Returns the maximum element, or `None` when the array is empty.
pub fn max_int(values : FixedArray[Int]) -> Int? {
  let len = values.length()
  if len == 0 {
    return None
  }
  let mut i = 0
  let mut vacc = @v128.i32x4_splat(0)
  let mut seeded = false
  while i + 4 <= len {
    let v = load4(values, i)
    vacc = if seeded { @v128.i32x4_max_s(vacc, v) } else { v }
    seeded = true
    i = i + 4
  }
  let mut result = if seeded {
    imax(
      imax(lane_int(vacc, 0), lane_int(vacc, 1)),
      imax(lane_int(vacc, 2), lane_int(vacc, 3)),
    )
  } else {
    values[0]
  }
  while i < len {
    result = imax(result, values[i])
    i = i + 1
  }
  Some(result)
}

///|
/// Returns whether the array is sorted in non-decreasing order.
pub fn is_sorted_int(values : FixedArray[Int]) -> Bool {
  let len = values.length()
  if len <= 1 {
    return true
  }
  let mut i = 0
  // each block checks the four adjacencies (i,i+1)..(i+3,i+4)
  while i + 5 <= len {
    let v0 = load4(values, i)
    let v1 = @v128.i32x4_const(
      values[i + 1].reinterpret_as_uint(),
      values[i + 2].reinterpret_as_uint(),
      values[i + 3].reinterpret_as_uint(),
      values[i + 4].reinterpret_as_uint(),
    )
    if @v128.i32x4_bitmask(@v128.i32x4_gt_s(v0, v1)) != 0 {
      return false
    }
    i = i + 4
  }
  while i + 1 < len {
    if values[i] > values[i + 1] {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn dmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn dmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Returns the sum of all elements. The accumulation is lane-partitioned, so
/// the result may differ from a strict sequential sum by floating-point
/// rounding.
pub fn sum_double(values : FixedArray[Double]) -> Double {
  let len = values.length()
  let mut acc = @v128.f64x2_splat(0.0)
  let mut i = 0
  while i + 2 <= len {
    acc = @v128.f64x2_add(acc, @v128.f64x2_const(values[i], values[i + 1]))
    i = i + 2
  }
  let mut total = @v128.f64x2_extract_lane(acc, 0) +
    @v128.f64x2_extract_lane(acc, 1)
  while i < len {
    total = total + values[i]
    i = i + 1
  }
  total
}

///|
/// Returns the minimum element, or `None` when the array is empty.
pub fn min_double(values : FixedArray[Double]) -> Double? {
  let len = values.length()
  if len == 0 {
    return None
  }
  let mut i = 0
  let mut vacc = @v128.f64x2_splat(0.0)
  let mut seeded = false
  while i + 2 <= len {
    let v = @v128.f64x2_const(values[i], values[i + 1])
    vacc = if seeded { @v128.f64x2_min(vacc, v) } else { v }
    seeded = true
    i = i + 2
  }
  let mut result = if seeded {
    dmin(@v128.f64x2_extract_lane(vacc, 0), @v128.f64x2_extract_lane(vacc, 1))
  } else {
    values[0]
  }
  while i < len {
    result = dmin(result, values[i])
    i = i + 1
  }
  Some(result)
}

///|
/// Returns the maximum element, or `None` when the array is empty.
pub fn max_double(values : FixedArray[Double]) -> Double? {
  let len = values.length()
  if len == 0 {
    return None
  }
  let mut i = 0
  let mut vacc = @v128.f64x2_splat(0.0)
  let mut seeded = false
  while i + 2 <= len {
    let v = @v128.f64x2_const(values[i], values[i + 1])
    vacc = if seeded { @v128.f64x2_max(vacc, v) } else { v }
    seeded = true
    i = i + 2
  }
  let mut result = if seeded {
    dmax(@v128.f64x2_extract_lane(vacc, 0), @v128.f64x2_extract_lane(vacc, 1))
  } else {
    values[0]
  }
  while i < len {
    result = dmax(result, values[i])
    i = i + 1
  }
  Some(result)
}
