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

### Numeric

- `quicksort` — opt-in v128 quicksort for `Int` / `UInt`, based on
  [Engineering Faster Sorters for Small Sets of Items](https://arxiv.org/pdf/2205.05982).

(Element-wise numeric kernels like reductions and prefix-sum are intentionally
*not* here — see "Backends & benchmarking" for why v128 can't beat a scalar
loop over `FixedArray[Int]` / `[Float]`.)

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

**Why there are no element-wise numeric kernels here.** MoonBit has no vector
load for `FixedArray[Int]` / `[Float]`, so a "SIMD" version must gather lanes
one at a time with `*_const`, whose overhead outweighs the vector op. Earlier
reduction and prefix-sum packages measured ~2–5× *slower* than a plain scalar
loop, so they were dropped — every kernel here genuinely beats scalar. The lone
numeric package, `quicksort`, is opt-in: it uses v128 sorting networks for small
runs and sorts ≈6× faster than the stdlib sort (the SIMD vs algorithmic share of
that win isn't separately measured).

Tests run on either backend (`moon test`, or `moon test --target native`).

## Workspace

This repo is a `moon` workspace. The root module is the `Yu-zh/fast` kernel
library above; application modules that build on it live under `application/`:

- [`application/infer`](application/infer) — `Yu-zh/infer`, a Llama-architecture
  inference runtime that depends on `Yu-zh/fast`. It loads real
  [llama2.c](https://github.com/karpathy/llama2.c) checkpoints (SIMD transformer
  kernels, forward pass with KV cache, BPE tokenizer, sampling, int8
  quantization) and has a CLI that generates text — see its README.
- [`application/search`](application/search) — `Yu-zh/search`, a grep-like
  literal search (`memmem` + `memchr`) reporting matching lines with numbers.
- [`application/dedup`](application/dedup) — `Yu-zh/dedup`, content-defined
  chunking + deduplication (rolling hash boundaries, `adler32`/`sha256` chunks).
- [`application/jq`](application/jq) — `Yu-zh/jq`, an NDJSON query tool
  (`memchr`/`memmem` + SIMD `json.minify`).
- [`application/csvq`](application/csvq) — `Yu-zh/csvq`, CSV analytics
  (`csv.split_records` + `atoi` aggregations).
- [`application/vision`](application/vision) — `Yu-zh/vision`, an int8 quantized
  MLP image classifier (`gemm_i8`).
- [`application/http`](application/http) — `Yu-zh/http`, an HTTP/1.x request
  parser (`memchr` scanning, case-insensitive headers via `ascii`).
- [`application/cidr`](application/cidr) — `Yu-zh/cidr`, IPv4 CIDR / allowlist
  matching (SIMD `ipv4.parse` + masked compare).
- [`application/bloom`](application/bloom) — `Yu-zh/bloom`, a Bloom filter hashed
  with SIMD `adler32`/`crc32`.
