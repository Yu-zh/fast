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

// Byte-frequency counting. The full 256-bin histogram is scalar: incrementing
// a bin per input byte is a scatter (data-dependent write), which v128 does
// not offer; a future scatter (or gather) intrinsic is what would vectorize
// `counts`. Counting a single byte value, however, is a pure compare-and-sum,
// so `count_of` runs in SIMD.

///|
/// Returns a 256-entry array where element `b` is the number of times byte
/// value `b` occurs in `bytes`.
pub fn counts(bytes : FixedArray[Byte]) -> FixedArray[Int] {
  let c : FixedArray[Int] = FixedArray::make(256, 0)
  for i in 0..<bytes.length() {
    let idx = bytes[i].to_int()
    c[idx] = c[idx] + 1
  }
  c
}

///|
/// Returns the number of occurrences of `needle` in `bytes`, scanning 16
/// bytes per step with `i8x16_eq` + `popcnt`.
pub fn count_of(bytes : FixedArray[Byte], needle : Byte) -> Int {
  let len = bytes.length()
  let n = @v128.i8x16_splat(needle)
  let mut i = 0
  let mut count = 0
  while i + 16 <= len {
    count = count +
      @v128.i8x16_bitmask(@v128.i8x16_eq(@v128.v128_load(bytes, i), n)).popcnt()
    i = i + 16
  }
  while i < len {
    if bytes[i] == needle {
      count = count + 1
    }
    i = i + 1
  }
  count
}
