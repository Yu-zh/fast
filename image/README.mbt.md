# `Yu-zh/fast/image`

Per-pixel image kernels over raw byte buffers — the building blocks of a filter
pipeline. `invert` (xor), `adjust_brightness` (saturating add/sub), and
`threshold` (unsigned compare) are pure per-byte maps; `grayscale_rgba`
deinterleaves an RGBA buffer with `i8x16_swizzle`, widens to 16-bit lanes,
applies the integer luma weights `(77*R + 150*G + 29*B) >> 8`, and narrows back
to one gray byte per pixel.

```mbt check
///|
test "readme: image" {
  // red and green pixels (RGBA) -> their luma values
  let rgba : FixedArray[Byte] = [255, 0, 0, 255, 0, 255, 0, 255]
  @test.assert_eq(@image.grayscale_rgba(rgba), [76, 149])
  let gray : FixedArray[Byte] = [10, 200, 128]
  @image.threshold(gray, 128)
  @test.assert_eq(gray, [0, 255, 255])
}
```
