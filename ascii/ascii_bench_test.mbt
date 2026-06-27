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
fn all_ascii_scalar(bytes : FixedArray[Byte]) -> Bool {
  for i in 0..<bytes.length() {
    if bytes[i] >= 0x80 {
      return false
    }
  }
  true
}

///|
fn skip_whitespace_scalar(bytes : FixedArray[Byte]) -> Int {
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b != b' ' && b != b'\t' && b != b'\n' && b != b'\r' {
      return i
    }
  }
  bytes.length()
}

///|
fn to_lower_ascii_scalar(bytes : FixedArray[Byte]) -> Unit {
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b >= b'A' && b <= b'Z' {
      bytes[i] = b | 0x20
    }
  }
}

///|
fn ascii_noise() -> FixedArray[Byte] {
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
test "bench all_ascii simd 64k" (it : @bench.T) {
  let bytes = ascii_noise()
  it.bench(fn() { it.keep(@ascii.all_ascii(bytes)) })
}

///|
test "bench all_ascii scalar 64k" (it : @bench.T) {
  let bytes = ascii_noise()
  it.bench(fn() { it.keep(all_ascii_scalar(bytes)) })
}

///|
test "bench skip_whitespace simd 64k" (it : @bench.T) {
  let bytes = FixedArray::make(BENCH_LEN, b' ')
  it.bench(fn() { it.keep(@ascii.skip_whitespace(bytes)) })
}

///|
test "bench skip_whitespace scalar 64k" (it : @bench.T) {
  let bytes = FixedArray::make(BENCH_LEN, b' ')
  it.bench(fn() { it.keep(skip_whitespace_scalar(bytes)) })
}

///|
test "bench to_lower simd 64k" (it : @bench.T) {
  let bytes = ascii_noise()
  it.bench(fn() { @ascii.to_lower_ascii(bytes) })
}

///|
test "bench to_lower scalar 64k" (it : @bench.T) {
  let bytes = ascii_noise()
  it.bench(fn() { to_lower_ascii_scalar(bytes) })
}
