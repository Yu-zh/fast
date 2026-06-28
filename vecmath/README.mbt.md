# `Yu-zh/fast/vecmath`

Light vector math over `FixedArray[Double]`: `dot`, `axpy` (`y += alpha*x`),
`scale`, `argmin`, and `argmax`. Lanes are gathered with `f64x2_const` and
combined two at a time; `dot` and the arg-reductions need no per-element
stores, so they get the most from the vector arithmetic. Floating-point
results can differ from a strict sequential evaluation by rounding.

```mbt check
///|
test "readme: vecmath" {
  let a : FixedArray[Double] = [1.0, 2.0, 3.0]
  let b : FixedArray[Double] = [4.0, 5.0, 6.0]
  @test.assert_eq(@vecmath.dot(a, b), 32.0)
  @test.assert_eq(@vecmath.argmax(a), Some(2))
}
```
