# `Yu-zh/infer`

A SIMD-accelerated, **Llama-architecture inference runtime** built on the
[`Yu-zh/fast`](../../) kernel library. It lives in this workspace as its own
module so the kernel library stays lean and independently published.

## What's implemented

- **SIMD transformer kernels** (f32): `matmul`, `rmsnorm`, `softmax`, `swiglu`,
  `rope`. The hot paths (`matmul`, `rmsnorm`) use `f32x4`; `softmax`/`silu`
  apply the transcendental `exp` per element; `rope` rotates pairs.
- **`Transformer::forward(token, pos)`** — the full Llama decoder step: token
  embedding → N layers (RMSNorm → RoPE self-attention with a KV cache and
  grouped-query support → RMSNorm → SwiGLU feed-forward, each with a residual)
  → final RMSNorm → logits. Cross-checked end to end against an independent
  f64 reference for both multi-head and grouped-query attention.
- **`generate(model, prompt, steps)`** — greedy autoregressive decoding over
  the KV cache.
- **`classify(...)`** — a small int8 dense-layer + argmax demo composing
  `Yu-zh/fast/gemm`.

## Not yet (the path to running a real checkpoint)

A BPE tokenizer, a checkpoint/GGUF loader, richer sampling (temperature,
top-k/top-p), and quantized (4-bit) weights for larger models. The forward
pass runs on in-memory f32 weights today — the [llama2.c](https://github.com/karpathy/llama2.c)
"stories" models are the intended first end-to-end target.

```mbt check
///|
test "readme: a transformer matmul kernel" {
  let x : FixedArray[Float] = [1.0, 2.0, 3.0]
  let w : FixedArray[Float] = [1.0, 0.0, 0.0, 1.0, 1.0, 1.0] // 2 rows x 3
  let out : FixedArray[Float] = FixedArray::make(2, 0.0)
  @infer.matmul(out, x, w, 3, 2)
  @test.assert_eq(out, [1.0, 6.0])
}
```

Building and running a model (sketch):

```moonbit nocheck
///|
let config = @infer.Config::{
  dim,
  hidden_dim,
  n_layers,
  n_heads,
  n_kv_heads,
  vocab_size,
  seq_len,
}

///|
let model = @infer.Transformer::new(config, weights)

///|
let tokens = @infer.generate(model, [bos_token], 64)
```
