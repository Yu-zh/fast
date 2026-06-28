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

// SHA-256 (FIPS 180-4). This is a scalar reference: the message-schedule and
// compression rounds carry strict data dependencies, and hardware SHA is done
// with dedicated crypto instructions (e.g. the x86 SHA extensions or ARMv8
// crypto), not general SIMD. The API is stable for when such intrinsics
// become available.

///|
let k : FixedArray[UInt] = [
  0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U, 0x923f82a4U,
  0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U, 0x72be5d74U, 0x80deb1feU,
  0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU,
  0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU, 0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
  0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU,
  0x53380d13U, 0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
  0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U, 0x19a4c116U,
  0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
  0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U, 0x90befffaU, 0xa4506cebU, 0xbef9a3f7U,
  0xc67178f2U,
]

///|
let h0 : FixedArray[UInt] = [
  0x6a09e667U, 0xbb67ae85U, 0x3c6ef372U, 0xa54ff53aU, 0x510e527fU, 0x9b05688cU, 0x1f83d9abU,
  0x5be0cd19U,
]

///|
fn rotr(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

///|
/// Computes the SHA-256 digest of `data` as 32 bytes.
pub fn hash(data : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = data.length()
  // pad: 0x80, then zeros, then the 64-bit big-endian bit length
  let total = (len + 9 + 63) / 64 * 64
  let msg : FixedArray[Byte] = FixedArray::make(total, 0)
  for i in 0..<len {
    msg[i] = data[i]
  }
  msg[len] = 0x80
  let bits = len.to_int64() * 8L
  for i in 0..<8 {
    msg[total - 1 - i] = ((bits >> (i * 8)).to_int() & 0xff).to_byte()
  }
  let h : FixedArray[UInt] = FixedArray::make(8, 0)
  for i in 0..<8 {
    h[i] = h0[i]
  }
  let w : FixedArray[UInt] = FixedArray::make(64, 0)
  let mut base = 0
  while base < total {
    for t in 0..<16 {
      let o = base + t * 4
      w[t] = (msg[o].to_uint() << 24) |
        (msg[o + 1].to_uint() << 16) |
        (msg[o + 2].to_uint() << 8) |
        msg[o + 3].to_uint()
    }
    for t in 16..<64 {
      let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
      let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
      w[t] = w[t - 16] + s0 + w[t - 7] + s1
    }
    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    let mut f = h[5]
    let mut g = h[6]
    let mut hh = h[7]
    for t in 0..<64 {
      let big_s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ ((e ^ 0xffffffffU) & g)
      let temp1 = hh + big_s1 + ch + k[t] + w[t]
      let big_s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let temp2 = big_s0 + maj
      hh = g
      g = f
      f = e
      e = d + temp1
      d = c
      c = b
      b = a
      a = temp1 + temp2
    }
    h[0] = h[0] + a
    h[1] = h[1] + b
    h[2] = h[2] + c
    h[3] = h[3] + d
    h[4] = h[4] + e
    h[5] = h[5] + f
    h[6] = h[6] + g
    h[7] = h[7] + hh
    base = base + 64
  }
  let out : FixedArray[Byte] = FixedArray::make(32, 0)
  for i in 0..<8 {
    out[i * 4] = (h[i] >> 24).to_byte()
    out[i * 4 + 1] = ((h[i] >> 16) & 0xffU).to_byte()
    out[i * 4 + 2] = ((h[i] >> 8) & 0xffU).to_byte()
    out[i * 4 + 3] = (h[i] & 0xffU).to_byte()
  }
  out
}
