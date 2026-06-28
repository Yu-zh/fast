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
// 256x256 RGBA image
const RGBA_LEN = 262144

///|
fn bench_rgba() -> FixedArray[Byte] {
  let a : FixedArray[Byte] = FixedArray::make(RGBA_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<RGBA_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    a[i] = (state & 0xff).to_byte()
  }
  a
}

///|
fn grayscale_scalar(rgba : FixedArray[Byte]) -> FixedArray[Byte] {
  let pixels = rgba.length() / 4
  let out : FixedArray[Byte] = FixedArray::make(pixels, 0)
  for p in 0..<pixels {
    let r = rgba[p * 4].to_int()
    let g = rgba[p * 4 + 1].to_int()
    let b = rgba[p * 4 + 2].to_int()
    out[p] = ((77 * r + 150 * g + 29 * b) >> 8).to_byte()
  }
  out
}

///|
test "bench grayscale simd 256x256" (it : @bench.T) {
  let rgba = bench_rgba()
  it.bench(fn() { it.keep(@image.grayscale_rgba(rgba)) })
}

///|
test "bench grayscale scalar 256x256" (it : @bench.T) {
  let rgba = bench_rgba()
  it.bench(fn() { it.keep(grayscale_scalar(rgba)) })
}
