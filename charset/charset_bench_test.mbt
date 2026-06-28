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
const BENCH_LEN = 65536

///|
fn alnum_charset() -> @charset.Charset {
  let allowed : FixedArray[Byte] = FixedArray::make(62, 0)
  let mut k = 0
  for c = b'A'; c <= b'Z'; c = c + 1 {
    allowed[k] = c
    k = k + 1
  }
  for c = b'a'; c <= b'z'; c = c + 1 {
    allowed[k] = c
    k = k + 1
  }
  for c = b'0'; c <= b'9'; c = c + 1 {
    allowed[k] = c
    k = k + 1
  }
  @charset.Charset::of(allowed)
}

///|
fn bench_text() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = b'a' + (state % 26U).to_byte()
  }
  bytes
}

///|
fn scalar_validate(cs : @charset.Charset, bytes : FixedArray[Byte]) -> Bool {
  for i in 0..<bytes.length() {
    if !cs.contains(bytes[i]) {
      return false
    }
  }
  true
}

///|
test "bench charset validate simd 64k" (it : @bench.T) {
  let cs = alnum_charset()
  let text = bench_text()
  it.bench(fn() { it.keep(cs.validate(text)) })
}

///|
test "bench charset validate scalar 64k" (it : @bench.T) {
  let cs = alnum_charset()
  let text = bench_text()
  it.bench(fn() { it.keep(scalar_validate(cs, text)) })
}
