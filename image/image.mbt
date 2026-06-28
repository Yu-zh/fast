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

// Per-pixel image kernels over raw byte buffers — the building blocks of an
// image filter pipeline. `invert`/`adjust_brightness`/`threshold` are pure
// per-byte maps (xor, saturating add/sub, unsigned compare). `grayscale_rgba`
// deinterleaves RGBA with `i8x16_swizzle`, widens to 16-bit lanes, applies the
// integer luma weights (77, 150, 29) / 256, and narrows back to bytes.

///|
/// Inverts every byte (`p -> 255 - p`).
pub fn invert(pixels : FixedArray[Byte]) -> Unit {
  let len = pixels.length()
  let ones = @v128.i8x16_splat(0xff)
  let mut i = 0
  while i + 16 <= len {
    @v128.v128_store(
      pixels,
      i,
      @v128.v128_xor(@v128.v128_load(pixels, i), ones),
    )
    i = i + 16
  }
  while i < len {
    pixels[i] = pixels[i] ^ 0xff
    i = i + 1
  }
}

///|
/// Adds `delta` to every byte with unsigned saturation (clamped to 0..255).
/// `delta` is itself clamped to -255..255.
pub fn adjust_brightness(pixels : FixedArray[Byte], delta : Int) -> Unit {
  let len = pixels.length()
  if delta == 0 {
    return
  }
  let mut i = 0
  if delta > 0 {
    let amount = if delta > 255 { 255 } else { delta }
    let d = @v128.i8x16_splat(amount.to_byte())
    while i + 16 <= len {
      @v128.v128_store(
        pixels,
        i,
        @v128.i8x16_add_sat_u(@v128.v128_load(pixels, i), d),
      )
      i = i + 16
    }
    while i < len {
      let v = pixels[i].to_int() + amount
      pixels[i] = (if v > 255 { 255 } else { v }).to_byte()
      i = i + 1
    }
  } else {
    let amount = if -delta > 255 { 255 } else { -delta }
    let d = @v128.i8x16_splat(amount.to_byte())
    while i + 16 <= len {
      @v128.v128_store(
        pixels,
        i,
        @v128.i8x16_sub_sat_u(@v128.v128_load(pixels, i), d),
      )
      i = i + 16
    }
    while i < len {
      let v = pixels[i].to_int() - amount
      pixels[i] = (if v < 0 { 0 } else { v }).to_byte()
      i = i + 1
    }
  }
}

///|
/// Binarizes in place: bytes `>= t` become 255, the rest 0.
pub fn threshold(gray : FixedArray[Byte], t : Byte) -> Unit {
  let len = gray.length()
  let tv = @v128.i8x16_splat(t)
  let mut i = 0
  while i + 16 <= len {
    // i8x16_ge_u yields 0xff where p >= t and 0 elsewhere — exactly the result
    @v128.v128_store(gray, i, @v128.i8x16_ge_u(@v128.v128_load(gray, i), tv))
    i = i + 16
  }
  while i < len {
    gray[i] = if gray[i] >= t { 255 } else { 0 }
    i = i + 1
  }
}

///|
let r_index : V128 = @v128.i8x16_const(
  0, 4, 8, 12, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff,
)

///|
let g_index : V128 = @v128.i8x16_const(
  1, 5, 9, 13, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff,
)

///|
let b_index : V128 = @v128.i8x16_const(
  2, 6, 10, 14, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff,
)

///|
/// Converts an interleaved RGBA buffer (4 bytes per pixel) to one grayscale
/// byte per pixel using the integer luma `(77*R + 150*G + 29*B) >> 8`.
pub fn grayscale_rgba(rgba : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = rgba.length()
  let pixels = len / 4
  let out : FixedArray[Byte] = FixedArray::make(pixels, 0)
  let wr = @v128.i16x8_splat(77)
  let wg = @v128.i16x8_splat(150)
  let wb = @v128.i16x8_splat(29)
  let mut i = 0
  let mut o = 0
  // four pixels (16 bytes) -> four gray bytes per step
  while i + 16 <= len {
    let v = @v128.v128_load(rgba, i)
    let r = @v128.i16x8_extend_low_i8x16_u(@v128.i8x16_swizzle(v, r_index))
    let g = @v128.i16x8_extend_low_i8x16_u(@v128.i8x16_swizzle(v, g_index))
    let b = @v128.i16x8_extend_low_i8x16_u(@v128.i8x16_swizzle(v, b_index))
    let gray = @v128.i16x8_shr_u(
      @v128.i16x8_add(
        @v128.i16x8_add(@v128.i16x8_mul(r, wr), @v128.i16x8_mul(g, wg)),
        @v128.i16x8_mul(b, wb),
      ),
      8,
    )
    @v128.v128_store32_lane(out, o, @v128.i8x16_narrow_i16x8_u(gray, gray), 0)
    i = i + 16
    o = o + 4
  }
  while i + 4 <= len {
    let r = rgba[i].to_int()
    let g = rgba[i + 1].to_int()
    let b = rgba[i + 2].to_int()
    out[o] = ((77 * r + 150 * g + 29 * b) >> 8).to_byte()
    i = i + 4
    o = o + 1
  }
  out
}
