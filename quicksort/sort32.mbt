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
let insertion_sort_limit = 24

///|
let lane_count = 4

///|
/// Sorts 32-bit signed integers by mutating `values` with a v128-assisted quicksort.
///
/// The sort is unstable. Partitioning compares four lanes at a time with
/// `moonbitlang/core/v128` and uses one scratch buffer; small partitions use
/// insertion sort and repeatedly imbalanced partitions fall back to heapsort.
pub fn sort_int(values : MutArrayView[Int]) -> Unit {
  let scratch : FixedArray[Int] = FixedArray::make(values.length(), 0)
  quick_sort_int(values, scratch.mut_view(), depth_limit(values.length()))
}

///|
/// Sorts 32-bit unsigned integers by mutating `values` with a v128-assisted quicksort.
///
/// The sort is unstable. Partitioning compares four lanes at a time with
/// `moonbitlang/core/v128` and uses one scratch buffer; small partitions use
/// insertion sort and repeatedly imbalanced partitions fall back to heapsort.
pub fn sort_uint(values : MutArrayView[UInt]) -> Unit {
  let scratch : FixedArray[UInt] = FixedArray::make(values.length(), 0U)
  quick_sort_uint(values, scratch.mut_view(), depth_limit(values.length()))
}

///|
fn quick_sort_int(
  values : MutArrayView[Int],
  scratch : MutArrayView[Int],
  limit : Int,
) -> Unit {
  for values = values, limit = limit {
    let len = values.length()
    if len <= insertion_sort_limit {
      insertion_sort(values)
      return
    }
    if limit == 0 {
      heap_sort(values)
      return
    }
    let (left_len, right_start) = partition_int(
      values,
      scratch,
      choose_pivot(values),
    )
    let right_len = len - right_start
    let next_limit = if minimum(left_len, right_len) < len / 8 {
      limit - 1
    } else {
      limit
    }
    if left_len < right_len {
      quick_sort_int(slice(values, 0, left_len), scratch, next_limit)
      continue slice(values, right_start, len), next_limit
    } else {
      quick_sort_int(slice(values, right_start, len), scratch, next_limit)
      continue slice(values, 0, left_len), next_limit
    }
  }
}

///|
fn quick_sort_uint(
  values : MutArrayView[UInt],
  scratch : MutArrayView[UInt],
  limit : Int,
) -> Unit {
  for values = values, limit = limit {
    let len = values.length()
    if len <= insertion_sort_limit {
      insertion_sort(values)
      return
    }
    if limit == 0 {
      heap_sort(values)
      return
    }
    let (left_len, right_start) = partition_uint(
      values,
      scratch,
      choose_pivot(values),
    )
    let right_len = len - right_start
    let next_limit = if minimum(left_len, right_len) < len / 8 {
      limit - 1
    } else {
      limit
    }
    if left_len < right_len {
      quick_sort_uint(slice(values, 0, left_len), scratch, next_limit)
      continue slice(values, right_start, len), next_limit
    } else {
      quick_sort_uint(slice(values, right_start, len), scratch, next_limit)
      continue slice(values, 0, left_len), next_limit
    }
  }
}

///|
fn partition_int(
  values : MutArrayView[Int],
  scratch : MutArrayView[Int],
  pivot_index : Int,
) -> (Int, Int) {
  let len = values.length()
  swap(values, pivot_index, len - 1)
  let pivot = values.unsafe_get(len - 1)
  let pivot_lanes = @v128.i32x4_splat(pivot.reinterpret_as_uint())
  let mut left = 0
  let mut right = len - 1
  let mut index = 0
  while index + lane_count <= len {
    let lanes = load_int_lanes(values, index)
    let less_mask = @v128.i32x4_bitmask(@v128.i32x4_lt_s(lanes, pivot_lanes))
    let greater_mask = @v128.i32x4_bitmask(@v128.i32x4_gt_s(lanes, pivot_lanes))
    for lane in 0..<lane_count {
      let value = @v128.i32x4_extract_lane(lanes, lane).reinterpret_as_int()
      let bit = 1 << lane
      if (less_mask & bit) != 0 {
        scratch.unsafe_set(left, value)
        left += 1
      } else if (greater_mask & bit) != 0 {
        scratch.unsafe_set(right, value)
        right -= 1
      }
    }
    index += lane_count
  }
  while index < len {
    let value = values.unsafe_get(index)
    if value < pivot {
      scratch.unsafe_set(left, value)
      left += 1
    } else if value > pivot {
      scratch.unsafe_set(right, value)
      right -= 1
    }
    index += 1
  }
  finish_partition(values, scratch, pivot, left, right)
}

///|
fn partition_uint(
  values : MutArrayView[UInt],
  scratch : MutArrayView[UInt],
  pivot_index : Int,
) -> (Int, Int) {
  let len = values.length()
  swap(values, pivot_index, len - 1)
  let pivot = values.unsafe_get(len - 1)
  let pivot_lanes = @v128.i32x4_splat(pivot)
  let mut left = 0
  let mut right = len - 1
  let mut index = 0
  while index + lane_count <= len {
    let lanes = load_uint_lanes(values, index)
    let less_mask = @v128.i32x4_bitmask(@v128.i32x4_lt_u(lanes, pivot_lanes))
    let greater_mask = @v128.i32x4_bitmask(@v128.i32x4_gt_u(lanes, pivot_lanes))
    for lane in 0..<lane_count {
      let value = @v128.i32x4_extract_lane(lanes, lane)
      let bit = 1 << lane
      if (less_mask & bit) != 0 {
        scratch.unsafe_set(left, value)
        left += 1
      } else if (greater_mask & bit) != 0 {
        scratch.unsafe_set(right, value)
        right -= 1
      }
    }
    index += lane_count
  }
  while index < len {
    let value = values.unsafe_get(index)
    if value < pivot {
      scratch.unsafe_set(left, value)
      left += 1
    } else if value > pivot {
      scratch.unsafe_set(right, value)
      right -= 1
    }
    index += 1
  }
  finish_partition(values, scratch, pivot, left, right)
}

///|
fn load_int_lanes(values : MutArrayView[Int], index : Int) -> V128 {
  @v128.i32x4_const(
    values.unsafe_get(index).reinterpret_as_uint(),
    values.unsafe_get(index + 1).reinterpret_as_uint(),
    values.unsafe_get(index + 2).reinterpret_as_uint(),
    values.unsafe_get(index + 3).reinterpret_as_uint(),
  )
}

///|
fn load_uint_lanes(values : MutArrayView[UInt], index : Int) -> V128 {
  @v128.i32x4_const(
    values.unsafe_get(index),
    values.unsafe_get(index + 1),
    values.unsafe_get(index + 2),
    values.unsafe_get(index + 3),
  )
}

///|
fn[T] finish_partition(
  values : MutArrayView[T],
  scratch : MutArrayView[T],
  pivot : T,
  left : Int,
  right : Int,
) -> (Int, Int) {
  for index in 0..<left {
    values.unsafe_set(index, scratch.unsafe_get(index))
  }
  for index in left..<(right + 1) {
    values.unsafe_set(index, pivot)
  }
  for index in (right + 1)..<values.length() {
    values.unsafe_set(index, scratch.unsafe_get(index))
  }
  (left, right + 1)
}

///|
fn[T : Compare] insertion_sort(values : MutArrayView[T]) -> Unit {
  for index in 1..<values.length() {
    for cursor = index
        cursor > 0 && values.unsafe_get(cursor - 1) > values.unsafe_get(cursor)
        cursor = cursor - 1 {
      swap(values, cursor, cursor - 1)
    }
  }
}

///|
fn[T : Compare] heap_sort(values : MutArrayView[T]) -> Unit {
  let len = values.length()
  for index in (len / 2)>..0 {
    sift_down(values, index)
  }
  for end in len>..1 {
    swap(values, 0, end)
    sift_down(slice(values, 0, end), 0)
  }
}

///|
fn[T : Compare] sift_down(values : MutArrayView[T], index : Int) -> Unit {
  let len = values.length()
  for index = index, child = index * 2 + 1; child < len; {
    let child = if child + 1 < len &&
      values.unsafe_get(child) < values.unsafe_get(child + 1) {
      child + 1
    } else {
      child
    }
    if values.unsafe_get(index) >= values.unsafe_get(child) {
      return
    }
    swap(values, index, child)
    continue child, child * 2 + 1
  }
}

///|
fn[T : Compare] choose_pivot(values : MutArrayView[T]) -> Int {
  let len = values.length()
  let first = len / 4
  let middle = len / 2
  let last = len - first - 1
  median_index(values, first, middle, last)
}

///|
fn[T : Compare] median_index(
  values : MutArrayView[T],
  first : Int,
  middle : Int,
  last : Int,
) -> Int {
  let a = values.unsafe_get(first)
  let b = values.unsafe_get(middle)
  let c = values.unsafe_get(last)
  if a < b {
    if b < c {
      middle
    } else if a < c {
      last
    } else {
      first
    }
  } else if a < c {
    first
  } else if b < c {
    last
  } else {
    middle
  }
}

///|
fn depth_limit(len : Int) -> Int {
  2 * log2_floor(len)
}

///|
fn log2_floor(len : Int) -> Int {
  for len = len, limit = 0; len > 1; {
    continue len / 2, limit + 1
  } nobreak {
    limit
  }
}

///|
fn minimum(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn[T] slice(
  values : MutArrayView[T],
  start : Int,
  end : Int,
) -> MutArrayView[T] {
  values.mut_view(start~, end~)
}

///|
fn[T] swap(values : MutArrayView[T], left : Int, right : Int) -> Unit {
  let tmp = values.unsafe_get(left)
  values.unsafe_set(left, values.unsafe_get(right))
  values.unsafe_set(right, tmp)
}
