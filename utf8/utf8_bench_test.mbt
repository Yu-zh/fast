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
fn ascii_input() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = (0x20U + (state & 0x3f)).to_byte()
  }
  bytes
}

///|
/// Mixed-width text: cycles ASCII, 2-byte, 3-byte, and 4-byte characters.
fn multibyte_input() -> FixedArray[Byte] {
  let pattern : FixedArray[Byte] = [
    b'h', b'i', b' ', 0xc3, 0xa9, 0xe4, 0xbd, 0xa0, 0xf0, 0x9f, 0x8e, 0x89,
  ]
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut i = 0
  while i + pattern.length() <= BENCH_LEN {
    for j in 0..<pattern.length() {
      bytes[i + j] = pattern[j]
    }
    i = i + pattern.length()
  }
  // pad the remainder with ASCII
  while i < BENCH_LEN {
    bytes[i] = b' '
    i = i + 1
  }
  bytes
}

///|
test "bench validate simd ascii 64k" (it : @bench.T) {
  let bytes = ascii_input()
  it.bench(fn() { it.keep(@utf8.validate(bytes)) })
}

///|
test "bench validate scalar ascii 64k" (it : @bench.T) {
  let bytes = ascii_input()
  it.bench(fn() { it.keep(validate_scalar(bytes)) })
}

///|
test "bench validate simd multibyte 64k" (it : @bench.T) {
  let bytes = multibyte_input()
  it.bench(fn() { it.keep(@utf8.validate(bytes)) })
}

///|
test "bench validate scalar multibyte 64k" (it : @bench.T) {
  let bytes = multibyte_input()
  it.bench(fn() { it.keep(validate_scalar(bytes)) })
}
