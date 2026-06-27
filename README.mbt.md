# `Yu-zh/fast`

Experimental SIMD-accelerated kernels for MoonBit, built on the v128 vector
intrinsics in `moonbitlang/core/v128`. The byte-processing packages mirror the
`moonbitlang/core/fast` experiments and operate over `FixedArray[Byte]`; the
numeric packages work over typed arrays. Each package has its own `README.md`
with a runnable example.

## Packages

- `ascii` — ASCII classification (`all_ascii`, `find_non_ascii`,
  `skip_whitespace`, `to_lower_ascii`).
- `hex` — lowercase hex `encode` / `decode`.
- `base64` — standard (RFC 4648) base64 `encode` / `decode`.
- `memchr` — single-byte search (`find_byte`, `find_last_byte`, `count_byte`).
- `memmem` — substring search (`find`, `find_last`, `count`, `contains`) using
  a first/last-byte probe with vectorized candidate filtering.
- `atoi` — decimal integer parsing (`parse_uint64`, `parse_int64`) that folds
  eight digits per step with a multiply-add chain.
- `utf8` — UTF-8 validation and UTF-8 ⇆ UTF-16LE transcoding.
- `json` — UTF-8 JSON parsing via a simdjson-style structural index pass, plus
  `minify` and `escape_string` for the serialization side.
- `escape` — web escaping (`html_escape`, `url_encode`) with a SIMD
  no-escape fast path.
- `csv` — RFC 4180 structural scanning (`unquoted_positions`,
  `split_records`) using a quote-parity prefix-XOR.
- `quicksort` — opt-in v128 quicksort for `Int` / `UInt` arrays, based on
  [Engineering Faster Sorters for Small Sets of Items](https://arxiv.org/pdf/2205.05982).
- `reduce` — vectorized reductions over numeric arrays (`sum_int`, `min_int`,
  `max_int`, `is_sorted_int`, and `Double` variants).

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

The v128 intrinsics lower to real SIMD instructions on the **native** backend
(SSE / NEON), where these kernels run several times faster than scalar code —
for example, on a 64 KiB workload, base64 encode ~6×, hex decode ~8×, and
substring search ~18×. On the **wasm-gc** backend (this module's
`preferred_target`) v128 currently runs through a scalar fallback, so the SIMD
paths are not faster there. Benchmark on native:

```bash
moon bench --target native
```

Tests run on either backend (`moon test`, or `moon test --target native`).
