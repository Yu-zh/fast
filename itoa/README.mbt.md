# `Yu-zh/fast/itoa`

SIMD integer formatting over `FixedArray[Byte]`: `format_uint64`,
`format_int64`, and `format_int`. An eight-digit group is expanded with two
reciprocal-multiply steps that need no `mulhi` — divide by 100 via
`x*5243 >> 19`, then by 10 via `n*103 >> 10` — and the digit lanes are
interleaved with `i8x16_shuffle` and biased to ASCII. A 64-bit value is up to
three such groups, with leading zeros trimmed. The inverse of `atoi`.

```mbt check
///|
test "readme: itoa" {
  let n42 : FixedArray[Byte] = [b'4', b'2']
  @test.assert_eq(@itoa.format_uint64(42UL), n42)
  let neg : FixedArray[Byte] = [b'-', b'7']
  @test.assert_eq(@itoa.format_int(-7), neg)
}
```
