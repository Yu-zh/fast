# `Yu-zh/fast`

Experimental SIMD-accelerated kernels for MoonBit, built on the v128 vector
intrinsics in `moonbitlang/core/v128`. The byte-processing packages mirror the
`moonbitlang/core/fast` experiments and operate over `FixedArray[Byte]`; the
numeric packages work over typed arrays. Each package has its own `README.md`
with a runnable example.

## Packages

### Bytes & text

- `ascii` — classification + case (`all_ascii`, `find_non_ascii`,
  `skip_whitespace`, `to_lower_ascii`, `to_upper_ascii`, `eq_ignore_case`).
- `hex` — lowercase hex `encode` / `decode`.
- `base64` — standard and URL-safe (RFC 4648) `encode` / `decode`.
- `base32` — standard (RFC 4648) base32 `encode` / `decode`.
- `charset` — arbitrary byte-set membership via a nibble-bitmap lookup.
- `memchr` — single-byte search (`find_byte`, `find_last_byte`, `count_byte`).
- `memmem` — substring search (`find`, `find_last`, `count`, `contains`).
- `utf8` — UTF-8 validation, UTF-8 ⇆ UTF-16LE / Latin-1 transcoding, codepoint
  counting.
- `escape` — web escaping (`html_escape`, `url_encode`).
- `json` — simdjson-style structural-index parsing, plus `minify` and
  `escape_string`.
- `csv` — RFC 4180 structural scanning via a quote-parity prefix-XOR.

### Numbers

- `atoi` — decimal integer parsing (`parse_uint64`, `parse_int64`).
- `itoa` — decimal integer formatting (`format_uint64`, `format_int64`).
- `ipv4` — IPv4 dotted-quad `parse` / `format`.

### Numeric arrays

- `quicksort` — opt-in v128 quicksort for `Int` / `UInt`, based on
  [Engineering Faster Sorters for Small Sets of Items](https://arxiv.org/pdf/2205.05982).
- `reduce` — reductions (`sum`/`min`/`max`/`is_sorted`) over `Int` / `Double`.
- `vecmath` — `dot`, `axpy`, `scale`, `argmin`, `argmax` over `Double`.
- `prefix_sum` — inclusive scan (Hillis-Steele) over `Int`.

### Checksums & hashing

- `adler32` — Adler-32 checksum (SIMD widening adds + `dot`).
- `crc32` — CRC-32/IEEE (table-based scalar; awaits a carryless-multiply
  intrinsic for SIMD folding).
- `sha256` — SHA-256 digest (scalar reference; awaits crypto intrinsics).
- `histogram` — byte-frequency `counts` (scalar; scatter not in v128) and a
  SIMD `count_of`.

### Applications

Larger packages that compose the kernels above into something closer to a real
workload:

- `vsearch` — vector similarity search: f32 `dot` / `l2_squared` / `cosine`,
  binary `hamming`, and a brute-force `top_k_cosine` (the distance core under
  semantic search / RAG).
- `image` — per-pixel image filters: `invert`, `adjust_brightness`,
  `threshold`, and RGBA `grayscale_rgba`.
- `gemm` — INT8 matrix multiply (`gemm_i8`) plus `relu_i32` / `argmax_i32`,
  enough to run a quantized MLP forward pass (a kernel + layer ops, not yet a
  full inference runtime).

## Examples

```mbt check
///|
test "base64 round-trips arbitrary bytes" {
  let data : FixedArray[Byte] = [b'f', b'o', b'o', b'b', b'a', b'r']
  @test.assert_eq(@base64.decode(@base64.encode(data)), Some(data))
}
```

```mbt check
///|
test "reduce over numeric arrays" {
  @test.assert_eq(@reduce.sum_int([1, 2, 3, 4, 5]), 15)
  @test.assert_eq(@reduce.max_int([5, -1, 3, 9, 0]), Some(9))
}
```

```mbt check
///|
test "sort Int values" {
  let values : FixedArray[Int] = [5, -1, 3, -1, 0]
  @quicksort.sort_int(values.mut_view())
  @test.assert_eq(values, [-1, -1, 0, 3, 5])
}
```

## Backends & benchmarking

v128 lowers to real SIMD on the **native** backend. Benchmark/run with
`--release --target native` — a debug build is ~100× slower, and the `wasm-gc`
backend currently runs v128 through a scalar fallback.

```bash
moon bench --target native
```

Measured SIMD-vs-scalar speedups (`moon bench --target native`, ~64 KiB inputs):

| package | kernel | speedup |
|---|---|---|
| `adler32` | `checksum` | ~35× |
| `charset` | `validate` | ~32× |
| `hex` | `encode` | ~21× |
| `memmem` | `find` | ~20× |
| `utf8` | `validate` | ~12× |
| `ascii` | `skip_whitespace`, `all_ascii` | ~10× |
| `memchr` | `find_byte` | ~9× |
| `hex` / `base64` | `decode` | ~6–8× |
| `base64` | `encode` | ~6× |
| `json` | `structural_indices` | ~5× |
| `image` | `grayscale_rgba` | ~5× |
| `gemm` | `gemm_i8` | ~4× |
| `csv` | `unquoted_positions` | ~3.5× |

**Every win comes from a byte-oriented kernel** — they use a true vector load
(`v128_load` over `FixedArray[Byte]`).

The **numeric packages over typed arrays do *not* benefit**: MoonBit has no
vector load for `FixedArray[Int]` / `[Float]`, so they gather lanes one at a
time with `*_const`, whose overhead outweighs the vector op. Measured,
`reduce.sum_int` / `max_int` are ~5× *slower* than scalar and
`prefix_sum.scan_int` ~2× slower; `vecmath.dot` only ~1.3×. They are correct,
but a plain scalar loop is faster until a typed vector load exists.

Tests run on either backend (`moon test`, or `moon test --target native`).

## Workspace

This repo is a `moon` workspace. The root module is the `Yu-zh/fast` kernel
library above; application modules that build on it live under `application/`:

- [`application/infer`](application/infer) — `Yu-zh/infer`, a Llama-architecture
  inference runtime that depends on `Yu-zh/fast`. It loads real
  [llama2.c](https://github.com/karpathy/llama2.c) checkpoints (SIMD transformer
  kernels, forward pass with KV cache, BPE tokenizer, sampling) and has a CLI
  that generates text — see its README.
