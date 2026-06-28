# `Yu-zh/jqbench`

A benchmark comparing [`Yu-zh/jq`](../jq) against two other MoonBit jq
implementations on the common task of **extracting a top-level field** (`.score`)
from a JSON document:

- [`shina1024/jqx`](https://mooncakes.io/docs/shina1024/jqx) `@0.2.0`
- [`mizchi/jq`](https://mooncakes.io/docs/mizchi/jq) `@0.2.2`

Run it (SIMD needs the native backend, release):

```bash
moon bench -p Yu-zh/jqbench --target native
```

## Results (native, `--release`)

| implementation | small object (~270 B) | larger object (~1.3 KB) |
|---|---|---|
| **`Yu-zh/jq`** (`field`) | **38.8 ns** | **179 ns** |
| `mizchi/jq` (`.score`) | 1.57 µs (40×) | 9.07 µs (51×) |
| `shina1024/jqx` (`.score`) | 4.22 µs (109×) | 27.3 µs (152×) |

`Yu-zh/jq` is **40–152× faster**, and the gap grows with document size.

## Why

It is not equivalent work — that is the design point. `Yu-zh/jq` locates
`"score":` with the SIMD substring search (`memmem`) and scans just the value
token, so its cost tracks *where the field is*, not the whole document.
`jqx` and `mizchi/jq` are general **jq-language engines**: they parse the entire
JSON into an AST, compile the filter, then evaluate it — and that full parse
scales with total size. For general queries (`.a.b[2] | select(...)`) you want a
real engine; `Yu-zh/jq` targets fast field extraction and line/substring
filtering, and can serve as a fast pre-filter in front of one.

All three are cross-checked to return the same value before timing.
