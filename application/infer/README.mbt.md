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

# generate — ALWAYS use --release on the native backend; a debug build is
# ~100x slower (256 tokens: ~2.7s release vs ~5min debug).
# args: <checkpoint> <tokenizer> [prompt] [steps] [temperature*100] [seed]
moon run application/infer/cmd/main --release --target native -- \
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
- **INT8 quantization** (`quant.mbt`): `QTransformer` quantizes the matmul
  weights to int8 on load (group size 16). The quantized matmul reads int8
  (4x less memory) and uses real SIMD — `v128_load` + `i32x4_dot_i16x8_s`,
  since int8, unlike a typed float array, has a vector load. This is the path
  `cmd/main` uses.
- **CLI** (`cmd/main`): reads the files (`moonbitlang/x/fs`), encodes, generates,
  and prints.

## Status & caveats

Always pass `--release` on native — a debug build is ~100x slower. With that,
on `stories15M`:

| build | 256 tokens (generation) | notes |
|------|------|------|
| f32 (`Transformer`)  | ~2.5s | full precision |
| **int8 (`QTransformer`, default)** | **~1.1s (~2.3x faster)** | ~4x less weight memory; output still fluent |

The matmul is still single-threaded; the remaining levers are multi-threading
and 4-bit quantization (which also makes 1B-class models feasible). The f32
`Transformer` remains for reference and is what the f64 cross-check tests use.

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
