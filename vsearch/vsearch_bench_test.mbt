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
const DIM = 768

///|
fn embedding(seed : UInt) -> FixedArray[Float] {
  let v : FixedArray[Float] = FixedArray::make(DIM, 0.0)
  let mut state = seed
  for i in 0..<DIM {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    v[i] = Float::from_int((state % 2000U).reinterpret_as_int() - 1000)
  }
  v
}

///|
fn dot_scalar(a : FixedArray[Float], b : FixedArray[Float]) -> Float {
  let mut s : Float = 0.0
  for i in 0..<a.length() {
    s = s + a[i] * b[i]
  }
  s
}

///|
test "bench cosine dot simd 768d" (it : @bench.T) {
  let a = embedding(1)
  let b = embedding(2)
  it.bench(fn() { it.keep(@vsearch.dot(a, b)) })
}

///|
test "bench cosine dot scalar 768d" (it : @bench.T) {
  let a = embedding(1)
  let b = embedding(2)
  it.bench(fn() { it.keep(dot_scalar(a, b)) })
}

///|
test "bench top_k over 1000 vectors" (it : @bench.T) {
  let query = embedding(0)
  let corpus : Array[FixedArray[Float]] = []
  for c in 0..<1000 {
    corpus.push(embedding(c.reinterpret_as_uint() + 10U))
  }
  it.bench(fn() { it.keep(@vsearch.top_k_cosine(query, corpus, 10)) })
}
