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

// SIMD set-membership over `FixedArray[Byte]` (the simdjson/Hyperscan "lookup"
// technique). A byte set is stored as a 16x16 bitmap split into two 16-byte
// tables indexed by the high nibble: `lo[hi]` holds the membership bits for
// low nibbles 0-7, `hi[hi]` for 8-15. Testing a byte is two `i8x16_swizzle`
// table lookups, a bit select, and a power-of-two `swizzle` to build the test
// bit (avoiding a per-lane variable shift, which v128 does not offer).

///|
/// Bit `i` of lane `i` — used to turn a bit index (0-7) into its mask.
let pow2 : V128 = @v128.i8x16_const(
  1, 2, 4, 8, 16, 32, 64, 128, 0, 0, 0, 0, 0, 0, 0, 0,
)

///|
/// A byte set represented as a nibble-indexed bitmap.
pub struct Charset {
  lo : FixedArray[Byte]
  hi : FixedArray[Byte]
}

///|
fn high_nibbles(v : V128) -> V128 {
  @v128.v128_and_(@v128.i16x8_shr_u(v, 4), @v128.i8x16_splat(0x0f))
}

///|
/// Builds a `Charset` containing exactly the bytes in `allowed`.
pub fn Charset::of(allowed : FixedArray[Byte]) -> Charset {
  let lo : FixedArray[Byte] = FixedArray::make(16, 0)
  let hi : FixedArray[Byte] = FixedArray::make(16, 0)
  for i in 0..<allowed.length() {
    let v = allowed[i].to_int()
    let h = v >> 4
    let l = v & 0x0f
    if l < 8 {
      lo[h] = lo[h] | (1 << l).to_byte()
    } else {
      hi[h] = hi[h] | (1 << (l - 8)).to_byte()
    }
  }
  Charset::{ lo, hi }
}

///|
/// Returns whether the single byte `b` is in the set.
pub fn Charset::contains(self : Charset, b : Byte) -> Bool {
  let v = b.to_int()
  let h = v >> 4
  let l = v & 0x0f
  let row = if l < 8 { self.lo[h] } else { self.hi[h] }
  let bit = if l < 8 { 1 << l } else { 1 << (l - 8) }
  (row.to_int() & bit) != 0
}

///|
/// Returns the index of the first byte at or after `from` that is not in the
/// set, or `None` if every byte from `from` on is in the set.
pub fn Charset::find_invalid(
  self : Charset,
  bytes : FixedArray[Byte],
  from? : Int = 0,
) -> Int? {
  let len = bytes.length()
  let lo_vec = @v128.v128_load(self.lo, 0)
  let hi_vec = @v128.v128_load(self.hi, 0)
  let nibble = @v128.i8x16_splat(0x0f)
  let eight = @v128.i8x16_splat(8)
  let seven = @v128.i8x16_splat(7)
  let mut i = if from < 0 { 0 } else { from }
  while i + 16 <= len {
    let c = @v128.v128_load(bytes, i)
    let rowlo = @v128.i8x16_swizzle(lo_vec, high_nibbles(c))
    let rowhi = @v128.i8x16_swizzle(hi_vec, high_nibbles(c))
    let ln = @v128.v128_and_(c, nibble)
    // pick the byte holding low nibbles 0-7 or 8-15, then test bit `ln & 7`
    let row = @v128.v128_bitselect(rowlo, rowhi, @v128.i8x16_lt_u(ln, eight))
    let bit = @v128.i8x16_swizzle(pow2, @v128.v128_and_(ln, seven))
    let hit = @v128.i8x16_eq(@v128.v128_and_(row, bit), bit)
    let mask = @v128.i8x16_bitmask(hit)
    if mask != 0xffff {
      return Some(i + (mask ^ 0xffff).ctz())
    }
    i = i + 16
  }
  while i < len {
    if !self.contains(bytes[i]) {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// Returns whether every byte of `bytes` is in the set.
pub fn Charset::validate(self : Charset, bytes : FixedArray[Byte]) -> Bool {
  self.find_invalid(bytes) is None
}
