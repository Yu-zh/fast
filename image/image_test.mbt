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
fn ramp(n : Int) -> FixedArray[Byte] {
  let a : FixedArray[Byte] = FixedArray::make(n, 0)
  for i in 0..<n {
    a[i] = ((i * 37 + 11) & 0xff).to_byte()
  }
  a
}

///|
test "invert" {
  let p : FixedArray[Byte] = [0, 1, 254, 255, 128]
  @image.invert(p)
  @test.assert_eq(p, [255, 254, 1, 0, 127])
  // SIMD path matches scalar over a longer buffer
  let big = ramp(40)
  let ref_ = ramp(40)
  for i in 0..<40 {
    ref_[i] = ref_[i] ^ 0xff
  }
  @image.invert(big)
  @test.assert_eq(big, ref_)
}

///|
test "adjust_brightness saturates" {
  let p : FixedArray[Byte] = [0, 100, 200, 255, 50]
  @image.adjust_brightness(p, 60)
  @test.assert_eq(p, [60, 160, 255, 255, 110])
  let q : FixedArray[Byte] = [0, 100, 200, 255, 50]
  @image.adjust_brightness(q, -60)
  @test.assert_eq(q, [0, 40, 140, 195, 0])
  // SIMD path on a full block
  let big : FixedArray[Byte] = FixedArray::make(32, 250)
  @image.adjust_brightness(big, 20)
  @test.assert_eq(big[0], 255)
}

///|
test "threshold" {
  let g : FixedArray[Byte] = [10, 127, 128, 200, 255, 0]
  @image.threshold(g, 128)
  @test.assert_eq(g, [0, 0, 255, 255, 255, 0])
}

///|
test "grayscale_rgba" {
  // pure red, green, blue, white, black pixels (RGBA)
  let rgba : FixedArray[Byte] = [
    255, 0, 0, 255, // red   -> 77*255>>8  = 76
     0, 255, 0, 255, // green -> 150*255>>8 = 149
     0, 0, 255, 255, // blue  -> 29*255>>8  = 28
     255, 255, 255, 255, // white -> 255
     0, 0, 0, 255, // black -> 0
  ]
  @test.assert_eq(@image.grayscale_rgba(rgba), [76, 149, 28, 255, 0])
}

///|
test "grayscale_rgba matches scalar across sizes" {
  for pixels in [1, 3, 4, 5, 16, 17, 64] {
    let rgba = ramp(pixels * 4)
    let expected : FixedArray[Byte] = FixedArray::make(pixels, 0)
    for p in 0..<pixels {
      let r = rgba[p * 4].to_int()
      let g = rgba[p * 4 + 1].to_int()
      let b = rgba[p * 4 + 2].to_int()
      expected[p] = ((77 * r + 150 * g + 29 * b) >> 8).to_byte()
    }
    @test.assert_eq(@image.grayscale_rgba(rgba), expected)
  }
}
