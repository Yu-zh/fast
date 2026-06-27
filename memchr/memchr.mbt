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
/// Returns the index of the first occurrence of `needle` at or after `from`,
/// or `None` if the byte does not occur.
pub fn find_byte(
  haystack : FixedArray[Byte],
  needle : Byte,
  from? : Int = 0,
) -> Int? {
  let len = haystack.length()
  let mut i = if from < 0 { 0 } else { from }
  let needles = @v128.i8x16_splat(needle)
  while i + 16 <= len {
    let eq = @v128.i8x16_eq(@v128.v128_load(haystack, i), needles)
    let mask = @v128.i8x16_bitmask(eq)
    if mask != 0 {
      return Some(i + mask.ctz())
    }
    i = i + 16
  }
  while i < len {
    if haystack[i] == needle {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Returns the index of the last occurrence of `needle`, or `None` if the
/// byte does not occur.
pub fn find_last_byte(haystack : FixedArray[Byte], needle : Byte) -> Int? {
  let len = haystack.length()
  let mut i = len
  let needles = @v128.i8x16_splat(needle)
  while i - 16 >= 0 {
    let eq = @v128.i8x16_eq(@v128.v128_load(haystack, i - 16), needles)
    let mask = @v128.i8x16_bitmask(eq)
    if mask != 0 {
      return Some(i - 16 + 31 - mask.clz())
    }
    i = i - 16
  }
  while i > 0 {
    if haystack[i - 1] == needle {
      return Some(i - 1)
    }
    i = i - 1
  }
  None
}

///|
/// Returns the number of occurrences of `needle`.
pub fn count_byte(haystack : FixedArray[Byte], needle : Byte) -> Int {
  let len = haystack.length()
  let mut i = 0
  let mut count = 0
  let needles = @v128.i8x16_splat(needle)
  while i + 16 <= len {
    let eq = @v128.i8x16_eq(@v128.v128_load(haystack, i), needles)
    count = count + @v128.i8x16_bitmask(eq).popcnt()
    i = i + 16
  }
  while i < len {
    if haystack[i] == needle {
      count = count + 1
    }
    i = i + 1
  }
  count
}
