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

// Content-defined chunking and deduplication (the rsync/restic idea). A
// polynomial rolling hash over a sliding window places chunk boundaries at
// content — so an insertion shifts only the local chunk, not everything after
// it. Each chunk is then keyed for dedup by `Yu-zh/fast`'s SIMD `adler32`
// (~35x, the library's biggest win) and identified by `sha256`. The rolling
// hash itself is inherently per-byte (scalar); the bulk per-chunk hashing is
// where SIMD pays off.

///|
const WINDOW = 48

///|
fn slice(d : FixedArray[Byte], start : Int, end : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(end - start, 0)
  for i in 0..<(end - start) {
    out[i] = d[start + i]
  }
  out
}

///|
fn bytes_eq(a : FixedArray[Byte], b : FixedArray[Byte]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// `131^e mod 2^32` (UInt wraparound), the weight of the byte leaving the window.
fn pow_base(e : Int) -> UInt {
  let mut r : UInt = 1
  for _ in 0..<e {
    r = r * 131
  }
  r
}

///|
/// Splits `data` into content-defined chunks, returned as `(start, len)` pairs.
/// A boundary is cut once the chunk is at least `min_size` and the rolling hash
/// has `mask` low bits clear (so the average chunk size is about `mask+1`), or
/// at `max_size`.
pub fn chunk(
  data : FixedArray[Byte],
  min_size : Int,
  mask : UInt,
  max_size : Int,
) -> Array[(Int, Int)] {
  let bounds : Array[(Int, Int)] = []
  let n = data.length()
  if n == 0 {
    return bounds
  }
  let pow = pow_base(WINDOW) // 131^WINDOW: weight of the byte leaving the window
  let mut h : UInt = 0
  let mut start = 0
  for i in 0..<n {
    h = h * 131 + data[i].to_int().reinterpret_as_uint()
    if i >= WINDOW {
      h = h - data[i - WINDOW].to_int().reinterpret_as_uint() * pow
    }
    let len = i - start + 1
    if (len >= min_size && (h & mask) == 0) || len >= max_size {
      bounds.push((start, len))
      start = i + 1
    }
  }
  if start < n {
    bounds.push((start, n - start))
  }
  bounds
}

///|
/// The result of deduplicating a buffer.
pub struct Dedup {
  bounds : Array[(Int, Int)] // chunks in file order
  sequence : Array[Int] // for each chunk, the index of its unique representative
  unique_count : Int // number of distinct chunks
}

///|
/// Chunks `data` and deduplicates identical chunks. `sequence[i]` is the
/// representative index of the i-th chunk; equal chunks share a representative.
pub fn dedup(
  data : FixedArray[Byte],
  min_size : Int,
  mask : UInt,
  max_size : Int,
) -> Dedup {
  let bounds = chunk(data, min_size, mask, max_size)
  let table : Map[UInt, Array[Int]] = Map([]) // weak hash -> unique indices
  let uniques : Array[FixedArray[Byte]] = []
  let sequence : Array[Int] = []
  for b in bounds {
    let block = slice(data, b.0, b.0 + b.1)
    let weak = @adler32.checksum(block) // SIMD weak hash / dedup key
    let mut found = -1
    match table.get(weak) {
      Some(bucket) =>
        for u in bucket {
          if bytes_eq(uniques[u], block) {
            found = u
            break
          }
        }
      None => ()
    }
    if found < 0 {
      found = uniques.length()
      uniques.push(block)
      match table.get(weak) {
        Some(bucket) => bucket.push(found)
        None => table[weak] = [found]
      }
    }
    sequence.push(found)
  }
  Dedup::{ bounds, sequence, unique_count: uniques.length() }
}

///|
/// The SHA-256 identity of the chunk at `[start, start+len)`.
pub fn digest(
  data : FixedArray[Byte],
  start : Int,
  len : Int,
) -> FixedArray[Byte] {
  @sha256.hash(slice(data, start, start + len))
}
