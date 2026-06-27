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
const BENCH_LEN = 49152

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
fn encode_scalar_bench(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let digits = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let len = bytes.length()
  let out : FixedArray[Byte] = FixedArray::make((len + 2) / 3 * 4, 0)
  let mut i = 0
  let mut o = 0
  while i + 3 <= len {
    let n0 = bytes[i].to_int()
    let n1 = bytes[i + 1].to_int()
    let n2 = bytes[i + 2].to_int()
    out[o] = digits[n0 >> 2]
    out[o + 1] = digits[((n0 & 0x03) << 4) | (n1 >> 4)]
    out[o + 2] = digits[((n1 & 0x0f) << 2) | (n2 >> 6)]
    out[o + 3] = digits[n2 & 0x3f]
    i = i + 3
    o = o + 4
  }
  out
}

///|
test "bench encode simd 48k" (it : @bench.T) {
  let bytes = bench_bytes()
  it.bench(fn() { it.keep(@base64.encode(bytes)) })
}

///|
test "bench encode scalar 48k" (it : @bench.T) {
  let bytes = bench_bytes()
  it.bench(fn() { it.keep(encode_scalar_bench(bytes)) })
}

///|
fn decode_value_scalar(b : Byte) -> Int {
  if b >= b'A' && b <= b'Z' {
    (b - b'A').to_int()
  } else if b >= b'a' && b <= b'z' {
    (b - b'a').to_int() + 26
  } else if b >= b'0' && b <= b'9' {
    (b - b'0').to_int() + 52
  } else if b == b'+' {
    62
  } else if b == b'/' {
    63
  } else {
    -1
  }
}

///|
fn decode_scalar(input : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = input.length()
  let sig = if len >= 1 && input[len - 1] == b'=' {
    if len >= 2 && input[len - 2] == b'=' {
      len - 2
    } else {
      len - 1
    }
  } else {
    len
  }
  let out : FixedArray[Byte] = FixedArray::make(sig / 4 * 3, 0)
  let mut i = 0
  let mut o = 0
  while i + 4 <= sig {
    let a = decode_value_scalar(input[i])
    let b = decode_value_scalar(input[i + 1])
    let c = decode_value_scalar(input[i + 2])
    let d = decode_value_scalar(input[i + 3])
    if (a | b | c | d) < 0 {
      return None
    }
    out[o] = ((a << 2) | (b >> 4)).to_byte()
    out[o + 1] = (((b & 0x0f) << 4) | (c >> 2)).to_byte()
    out[o + 2] = (((c & 0x03) << 6) | d).to_byte()
    i = i + 4
    o = o + 3
  }
  Some(out)
}

///|
test "bench decode simd 64k" (it : @bench.T) {
  let encoded = @base64.encode(bench_bytes())
  it.bench(fn() { it.keep(@base64.decode(encoded)) })
}

///|
test "bench decode scalar 64k" (it : @bench.T) {
  let encoded = @base64.encode(bench_bytes())
  it.bench(fn() { it.keep(decode_scalar(encoded)) })
}
