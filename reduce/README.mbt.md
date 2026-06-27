# `Yu-zh/fast/reduce`

SIMD reductions over numeric arrays: `sum_int`, `min_int`, `max_int`,
`is_sorted_int`, and the `Double` variants `sum_double` / `min_double` /
`max_double`. Lanes are gathered the way `quicksort` does (`i32x4_const` /
`f64x2_const`) and combined with vector arithmetic, then a horizontal merge and
a scalar tail. Integer sums wrap on 32-bit overflow like a scalar `+`;
floating-point sums are lane-partitioned, so they can differ from a strict
sequential sum by rounding.

```mbt check
///|
test "readme: reduce" {
  let xs : FixedArray[Int] = [5, -1, 3, 9, 0]
  @test.assert_eq(@reduce.max_int(xs), Some(9))
  @test.assert_eq(@reduce.is_sorted_int(xs), false)
  let ys : FixedArray[Int] = [1, 2, 3, 4, 5]
  @test.assert_eq(@reduce.sum_int(ys), 15)
}
```
