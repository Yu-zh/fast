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

// CRC-32 (IEEE 802.3, the zlib/gzip variant), reflected, polynomial
// 0xEDB88320. This is the classic byte-at-a-time table method and is scalar:
// a SIMD "folding" CRC needs a carryless multiply (PCLMULQDQ / VMULL), which
// v128 does not currently expose. When such an intrinsic lands, this is the
// package to revisit; the public API would be unchanged.

///|
/// Precomputed CRC-32 byte table (built once at module load).
let table : FixedArray[UInt] = build_table()

///|
fn build_table() -> FixedArray[UInt] {
  let t : FixedArray[UInt] = FixedArray::make(256, 0)
  for n in 0..<256 {
    let mut c = n.reinterpret_as_uint()
    for _ in 0..<8 {
      c = if (c & 1U) != 0U { 0xEDB88320U ^ (c >> 1) } else { c >> 1 }
    }
    t[n] = c
  }
  t
}

///|
/// Computes the CRC-32 (IEEE) checksum of `data`.
pub fn checksum(data : FixedArray[Byte]) -> UInt {
  let mut crc = 0xFFFFFFFFU
  for i in 0..<data.length() {
    let index = ((crc ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()
    crc = table[index] ^ (crc >> 8)
  }
  crc ^ 0xFFFFFFFFU
}
