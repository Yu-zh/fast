# `Yu-zh/infer`

A SIMD-accelerated, **Llama-architecture inference runtime** built on the
[`Yu-zh/fast`](../../) kernel library — it loads and runs real
[llama2.c](https://github.com/karpathy/llama2.c) checkpoints (e.g.
`stories15M`) and generates text. It lives in this workspace as its own module
so the kernel library stays lean and independently published.

## Run it

```bash
# get a tiny trained model + the tokenizer
curl -L -o stories15M.bin https://huggingface.co/karpathy/tinyllamas/resolve/main/stories15M.bin
curl -L -o tokenizer.bin  https://github.com/karpathy/llama2.c/raw/master/tokenizer.bin

# generate (native is required for speed — v128 lowers to real SIMD there)
# args: <checkpoint> <tokenizer> [prompt] [steps] [temperature*100] [seed]
moon run application/infer/cmd/main --target native -- \
    stories15M.bin tokenizer.bin "Once upon a time" 256 0
```

Sample output (greedy, `temperature 0`):

> Once upon a time, there was a little girl named Lily. She loved to play
> outside in the sunshine. One day, she saw a big, red ball in the sky. It was
> the sun! She thought it was so pretty. …

## Components

- **Kernels** (`kernels.mbt`): `matmul`/`rmsnorm` on `f32x4`, plus `softmax`,
  `swiglu`, `rope`.
- **Forward pass** (`model.mbt`): `Transformer::forward(token, pos)` — the full
  Llama decoder (embedding → RMSNorm → RoPE attention with KV cache and
  grouped-query support → RMSNorm → SwiGLU FFN, residuals → final norm →
  logits). Cross-checked against an independent f64 reference.
- **Generation / sampling**: `generate` (greedy) and `sample` (greedy /
  temperature / top-p) with a seeded `Rng`.
- **Checkpoint loader** (`loader.mbt`): `load_checkpoint(Bytes)` parses the
  llama2.c `.bin` format.
- **Tokenizer** (`tokenizer.mbt`): `Tokenizer::from_bytes` + SentencePiece-style
  BPE `encode` / `decode`.
- **CLI** (`cmd/main`): reads the files (`moonbitlang/x/fs`), encodes, generates,
  and prints.

## Status & caveats

This is **correctness-first, not optimized**: the matmul gathers `f32x4` lanes
element-by-element (there is no vector load for typed arrays) and isn't tiled or
threaded, so generation is slow — expect minutes for a few hundred tokens of
`stories15M` on native. Use a small step count for quick experiments. Natural
next steps: faster matmul, 4-bit quantization for larger models, and richer
sampling controls.

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
