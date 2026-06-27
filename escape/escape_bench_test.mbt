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
/// Mostly plain text with a sprinkling of specials, the realistic case where
/// the SIMD no-escape fast path dominates.
fn bench_text() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, b'a')
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = if state % 32U == 0U {
      b'<'
    } else {
      b'a' + (state % 26U).to_byte()
    }
  }
  bytes
}

///|
fn html_escape_scalar(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let mut total = 0
  for i in 0..<len {
    let b = bytes[i]
    total = total +
      (if b == b'&' {
        5
      } else if b == b'<' || b == b'>' {
        4
      } else if b == b'"' {
        6
      } else if b == b'\'' {
        5
      } else {
        1
      })
  }
  let out : FixedArray[Byte] = FixedArray::make(total, 0)
  let mut o = 0
  for i in 0..<len {
    let b = bytes[i]
    if b == b'<' {
      out[o] = b'&'
      out[o + 1] = b'l'
      out[o + 2] = b't'
      out[o + 3] = b';'
      o = o + 4
    } else {
      out[o] = b
      o = o + 1
    }
  }
  out
}

///|
test "bench html_escape simd 64k" (it : @bench.T) {
  let text = bench_text()
  it.bench(fn() { it.keep(@escape.html_escape(text)) })
}

///|
test "bench html_escape scalar 64k" (it : @bench.T) {
  let text = bench_text()
  it.bench(fn() { it.keep(html_escape_scalar(text)) })
}

///|
test "bench url_encode simd 64k" (it : @bench.T) {
  let text = bench_text()
  it.bench(fn() { it.keep(@escape.url_encode(text)) })
}
