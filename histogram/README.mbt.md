# `Yu-zh/fast/histogram`

Byte-frequency counting over `FixedArray[Byte]`. `counts` returns all 256 bins
and is **scalar**: incrementing a bin per input byte is a scatter
(data-dependent write), which `v128` does not offer — a future scatter/gather
intrinsic is what would vectorize it. Counting a single byte value, however, is
a pure compare-and-sum, so `count_of` runs in SIMD (`i8x16_eq` + `popcnt`).

```mbt check
///|
test "readme: histogram" {
  let data : FixedArray[Byte] = [b'b', b'a', b'n', b'a', b'n', b'a']
  let c = @histogram.counts(data)
  @test.assert_eq(c[b'a'.to_int()], 3)
  @test.assert_eq(@histogram.count_of(data, b'n'), 2)
}
```
