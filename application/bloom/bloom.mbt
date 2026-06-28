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

// A Bloom filter: a probabilistic set with no false negatives. Membership is
// recorded in a bit array, indexed by `k` hash probes per key. The two base
// hashes come from `Yu-zh/fast` — Adler-32 and CRC-32, both SIMD kernels — and
// the `k` probes are derived by double hashing (`h1 + i*h2`, Kirsch-Mitzenmacher)
// so each key is hashed only twice regardless of `k`.

///|
/// A Bloom filter over `m` bits with `k` hash probes.
pub struct Bloom {
  bits : FixedArray[Byte]
  m : Int
  k : Int
}

///|
/// Creates an empty filter with `bits` bits (rounded up to a byte) and `probes`
/// hashes per key. Pick `bits ≈ -n*ln(p)/ln(2)^2` and `probes ≈ bits/n*ln(2)`
/// for `n` items at false-positive rate `p`.
pub fn Bloom::new(bits : Int, probes : Int) -> Bloom {
  let m = if bits < 8 { 8 } else { bits }
  Bloom::{
    bits: FixedArray::make((m + 7) / 8, 0),
    m,
    k: if probes < 1 {
      1
    } else {
      probes
    },
  }
}

///|
/// The bit index of probe `i` for `key`, via double hashing of Adler-32/CRC-32.
fn Bloom::probe(self : Bloom, h1 : UInt, h2 : UInt, i : Int) -> Int {
  let m = self.m.reinterpret_as_uint()
  ((h1 + i.reinterpret_as_uint() * h2) % m).reinterpret_as_int()
}

///|
/// Inserts `key` into the filter.
pub fn Bloom::add(self : Bloom, key : FixedArray[Byte]) -> Unit {
  let h1 = @adler32.checksum(key)
  let h2 = @crc32.checksum(key) | 1 // odd, so it is coprime-ish with m and != 0
  for i in 0..<self.k {
    let idx = self.probe(h1, h2, i)
    let j = idx >> 3
    self.bits[j] = (self.bits[j].to_int() | (1 << (idx & 7))).to_byte()
  }
}

///|
/// Tests membership. `false` is exact (definitely absent); `true` may be a
/// false positive (probably present).
pub fn Bloom::contains(self : Bloom, key : FixedArray[Byte]) -> Bool {
  let h1 = @adler32.checksum(key)
  let h2 = @crc32.checksum(key) | 1
  for i in 0..<self.k {
    let idx = self.probe(h1, h2, i)
    if (self.bits[idx >> 3].to_int() & (1 << (idx & 7))) == 0 {
      return false
    }
  }
  true
}
