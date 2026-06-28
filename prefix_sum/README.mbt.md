# `Yu-zh/fast/prefix_sum`

SIMD inclusive prefix sum (scan) over `FixedArray[Int]`. Each block of four
lanes is scanned with a two-step Hillis-Steele pass — add the vector shifted
right by one lane, then by two — using `i8x16_shuffle` against a zero vector,
with a scalar carry threading the running total between blocks. Sums wrap on
32-bit overflow, matching a scalar `+` accumulation.

```mbt check
///|
test "readme: prefix_sum" {
  let values : FixedArray[Int] = [1, 2, 3, 4]
  @test.assert_eq(@prefix_sum.scan_int(values), [1, 3, 6, 10])
}
```
