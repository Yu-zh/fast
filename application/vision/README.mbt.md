# `Yu-zh/vision`

An INT8 quantized two-layer MLP image classifier (MNIST-shaped inputs), built
on [`Yu-zh/fast`](../../). Each layer is the SIMD int8 matrix multiply
(`gemm.gemm_i8`, `i32x4_dot_i16x8_s`) plus `relu_i32`; activations are
requantized to int8 between layers, and `argmax_i32` reduces the final logits.
It's the same int8 approach as the [`Yu-zh/infer`](../infer) transformer, scaled
down to a classifier.

```mbt check
///|
test "readme: classify by the strongest feature" {
  // a 3->3->3 identity network: prediction = argmax(input)
  let id : FixedArray[Byte] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
  let m = @vision.MLP::new(id, id, 3, 3, 3, 0)
  @test.assert_eq(m.classify([10, 90, 30]), 1)
}
```

Provide `w1` (`[hidden x in_dim]`) and `w2` (`[out_dim x hidden]`) as int8
row-major weights; `center` maps 0-255 grayscale pixels to signed int8 for
input. `classify` returns the predicted class; `logits` the raw int32 outputs.
