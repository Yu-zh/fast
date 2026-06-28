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
fn rnd(n : Int, seed : UInt) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(n, 0)
  let mut s = seed
  for i in 0..<n {
    s = s * 1664525 + 1013904223
    out[i] = ((s >> 24) & 0xFF).reinterpret_as_int().to_byte()
  }
  out
}

///|
fn repeat(pat : FixedArray[Byte], times : Int) -> FixedArray[Byte] {
  let m = pat.length()
  let out : FixedArray[Byte] = FixedArray::make(m * times, 0)
  for t in 0..<times {
    for i in 0..<m {
      out[t * m + i] = pat[i]
    }
  }
  out
}

///|
fn seq_eq(a : Array[Int], b : Array[Int]) -> Bool {
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
test "repeated content deduplicates" {
  let data = repeat(rnd(512, 7), 6)
  let r = @dedup.dedup(data, 32, 0x3F, 256)
  @test.assert_eq(r.sequence.length(), r.bounds.length())
  // heavily repeated input must collapse to far fewer unique chunks
  @test.assert_eq(r.unique_count < r.bounds.length(), true)
}

///|
test "chunking and dedup are deterministic" {
  let data = repeat(rnd(300, 99), 5)
  let a = @dedup.dedup(data, 32, 0x3F, 256)
  let b = @dedup.dedup(data, 32, 0x3F, 256)
  @test.assert_eq(a.unique_count, b.unique_count)
  @test.assert_eq(seq_eq(a.sequence, b.sequence), true)
}

///|
test "distinct content is never merged" {
  let data = rnd(2048, 1234)
  let r = @dedup.dedup(data, 32, 0x3F, 256)
  @test.assert_eq(r.unique_count, r.bounds.length())
}

///|
test "digest is stable for identical chunks" {
  let data = repeat(rnd(64, 5), 2) // two identical halves
  @test.assert_eq(@dedup.digest(data, 0, 64), @dedup.digest(data, 64, 64))
}
