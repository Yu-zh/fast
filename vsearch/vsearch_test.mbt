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
fn bytes(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  for i in 0..<s.length() {
    out[i] = s[i]
  }
  out
}

///|
test "dot and l2_squared" {
  let a : FixedArray[Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
  let b : FixedArray[Float] = [1.0, 1.0, 1.0, 1.0, 1.0]
  @test.assert_eq(@vsearch.dot(a, b), 15.0)
  let p : FixedArray[Float] = [0.0, 0.0, 0.0]
  let q : FixedArray[Float] = [3.0, 4.0, 0.0]
  @test.assert_eq(@vsearch.l2_squared(p, q), 25.0)
}

///|
test "cosine" {
  // orthogonal -> 0, parallel -> 1
  let x : FixedArray[Float] = [1.0, 0.0]
  let y : FixedArray[Float] = [0.0, 1.0]
  @test.assert_eq(@vsearch.cosine(x, y), 0.0)
  let a : FixedArray[Float] = [1.0, 2.0, 2.0]
  let b : FixedArray[Float] = [2.0, 4.0, 4.0]
  @test.assert_eq(@vsearch.cosine(a, b), 1.0)
  // zero vector -> 0
  let z : FixedArray[Float] = [0.0, 0.0, 0.0]
  @test.assert_eq(@vsearch.cosine(a, z), 0.0)
}

///|
test "hamming" {
  // 0xB0 = 1011_0000 has 3 set bits
  @test.assert_eq(@vsearch.hamming(bytes(b"\xB0"), bytes(b"\x00")), 3)
  @test.assert_eq(@vsearch.hamming(bytes(b"\xFF\xFF"), bytes(b"\x00\x00")), 16)
  @test.assert_eq(@vsearch.hamming(bytes(b"abc"), bytes(b"abc")), 0)
  // a 20-byte pair exercises the SIMD body and scalar tail
  let p : FixedArray[Byte] = FixedArray::make(20, 0xFF)
  let q : FixedArray[Byte] = FixedArray::make(20, 0x0F)
  @test.assert_eq(@vsearch.hamming(p, q), 20 * 4)
}

///|
test "top_k_cosine returns nearest by index order" {
  let query : FixedArray[Float] = [1.0, 0.0, 0.0]
  let corpus : Array[FixedArray[Float]] = [
    [0.0, 1.0, 0.0], // orthogonal, score 0
    [1.0, 1.0, 0.0], // 45 deg, score ~0.707
    [2.0, 0.0, 0.0], // parallel, score 1
    [-1.0, 0.0, 0.0], // opposite, score -1
  ]
  let top = @vsearch.top_k_cosine(query, corpus, 2)
  let indices = []
  for pair in top {
    let (idx, _) = pair
    indices.push(idx)
  }
  @test.assert_eq(indices, [2, 1])
}

///|
test "dot matches scalar reference" {
  for len in [0, 1, 4, 5, 7, 16, 17, 100] {
    let a : FixedArray[Float] = FixedArray::make(len, 0.0)
    let b : FixedArray[Float] = FixedArray::make(len, 0.0)
    let mut state = 0x2545f491
    for i in 0..<len {
      state = state * 1103515245 + 12345
      a[i] = Float::from_int((state >> 16) % 100)
      state = state * 1103515245 + 12345
      b[i] = Float::from_int((state >> 16) % 100)
    }
    let mut d : Float = 0.0
    for i in 0..<len {
      d = d + a[i] * b[i]
    }
    @test.assert_eq(@vsearch.dot(a, b), d)
  }
}
