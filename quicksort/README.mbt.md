# `Yu-zh/fast/quicksort`

This package provides opt-in quicksort entry points that use
`moonbitlang/core/v128` for 32-bit integer partitioning.

The v128 partitioning experiment is based on the SIMD quicksort approach
described in [Engineering Faster Sorters for Small Sets of Items](https://arxiv.org/pdf/2205.05982).

```mbt check
///|
test "sort Int values" {
  let values : FixedArray[Int] = [5, -1, 3, -1, 0]
  @quicksort.sort_int(values.mut_view())
  @test.assert_eq(values, [-1, -1, 0, 3, 5])
}
```

```mbt check
///|
test "sort UInt values" {
  let values : FixedArray[UInt] = [3U, 0xffffffffU, 0U, 3U]
  @quicksort.sort_uint(values.mut_view())
  @test.assert_eq(values, [0U, 3U, 3U, 0xffffffffU])
}
```
