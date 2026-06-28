# `Yu-zh/infer`

A SIMD-accelerated inference runtime built on the [`Yu-zh/fast`](../../) kernel
library. It lives in this workspace as a separate module so the kernel library
stays lean and independently published, while the runtime (which will grow a
tokenizer, a checkpoint loader, and model-specific glue) versions on its own.

Today it is a seed — a single quantized dense layer plus argmax, composing
`Yu-zh/fast/gemm` — enough to prove the cross-module wiring. Planned packages:
`rmsnorm`, `softmax`, `silu`/SwiGLU, `rope`, attention + KV cache, a BPE
tokenizer, and a checkpoint loader, building toward a small Llama-architecture
model (llama2.c-style) running end to end.

```mbt check
///|
test "readme: infer classify" {
  let input : FixedArray[Byte] = [1, 2, 3]
  let weights : FixedArray[Byte] = [1, 0, 0, 0, 1, 1, 0, 0, 0]
  // logits [1, 5, 0] -> class 1
  @test.assert_eq(@infer.classify(input, weights, 3, 3), 1)
}
```
