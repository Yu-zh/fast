# `Yu-zh/fast/gemm`

INT8 matrix multiply — the hot kernel under quantized neural-network inference —
plus `relu_i32` and `argmax_i32`, enough to compose a quantized MLP forward
pass (`dense -> relu -> dense -> argmax`). `gemm_i8` widens int8 lanes to int16
(signed) and reduces with `i32x4_dot_i16x8_s` (madd), accumulating in int32;
`B` is supplied transposed (`n x k`, row-major) so each output reads two
contiguous rows.

This is a correctness-first kernel plus a couple of layer ops, **not a full
runtime**: there is no requantization/bias, convolution, or softmax yet, and
the GEMM is a naive triple loop (no tiling). Those are the natural next steps.

```mbt check
///|
test "readme: gemm" {
  // a (1x3) times Bt (2x3, B transposed) -> logits (1x2), then pick the class
  let a : FixedArray[Byte] = [1, 2, 3]
  let bt : FixedArray[Byte] = [1, 0, 0, 0, 1, 1]
  let logits = @gemm.gemm_i8(a, bt, 1, 3, 2)
  @test.assert_eq(logits, [1, 5])
  @test.assert_eq(@gemm.argmax_i32(logits), Some(1))
}
```
