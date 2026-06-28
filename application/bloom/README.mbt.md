# `Yu-zh/bloom`

A Bloom filter — a compact probabilistic set with **no false negatives** —
built on [`Yu-zh/fast`](../../). The two base hashes are SIMD checksums
(`adler32` + `crc32`), and the `k` probes are derived by double hashing, so each
key is hashed only twice no matter how many probes you use.

```mbt check
///|
test "readme: membership never has false negatives" {
  let f = @bloom.Bloom::new(4096, 5) // 4096 bits, 5 probes
  f.add(of(b"alice"))
  f.add(of(b"bob"))
  @test.assert_eq(f.contains(of(b"alice")), true)
  @test.assert_eq(f.contains(of(b"carol")), false)
}
```

`contains` returning `false` is exact; `true` may be a false positive. Size
with `bits ≈ -n·ln(p)/ln(2)²` and `probes ≈ bits/n·ln(2)` for `n` items at rate
`p`.
