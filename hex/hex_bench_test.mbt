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
fn decode_nibble_scalar(b : Byte) -> Int {
  if b >= b'0' && b <= b'9' {
    (b - b'0').to_int()
  } else {
    let folded = b | 0x20
    if folded >= b'a' && folded <= b'f' {
      (folded - b'a').to_int() + 10
    } else {
      -1
    }
  }
}

///|
fn decode_scalar(hex : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = hex.length()
  if len % 2 != 0 {
    return None
  }
  let out : FixedArray[Byte] = FixedArray::make(len / 2, 0)
  let mut i = 0
  while i < len {
    let hi = decode_nibble_scalar(hex[i])
    let lo = decode_nibble_scalar(hex[i + 1])
    if hi < 0 || lo < 0 {
      return None
    }
    out[i / 2] = ((hi << 4) | lo).to_byte()
    i = i + 2
  }
  Some(out)
}

///|
fn bench_bytes() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = (state & 0xff).to_byte()
  }
  bytes
}

///|
test "bench encode simd 64k" (it : @bench.T) {
  let bytes = bench_bytes()
  it.bench(fn() { it.keep(@hex.encode(bytes)) })
}

///|
test "bench encode scalar 64k" (it : @bench.T) {
  let bytes = bench_bytes()
  it.bench(fn() { it.keep(encode_scalar(bytes)) })
}

///|
test "bench decode simd 128k" (it : @bench.T) {
  let hex = @hex.encode(bench_bytes())
  it.bench(fn() { it.keep(@hex.decode(hex)) })
}

///|
test "bench decode scalar 128k" (it : @bench.T) {
  let hex = @hex.encode(bench_bytes())
  it.bench(fn() { it.keep(decode_scalar(hex)) })
}
