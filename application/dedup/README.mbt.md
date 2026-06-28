# `Yu-zh/dedup`

Content-defined chunking and deduplication (the rsync/restic idea), built on
[`Yu-zh/fast`](../../). A polynomial rolling hash places chunk boundaries at
*content*, so an edit shifts only the local chunk. Each chunk is keyed for
dedup by the SIMD `adler32` checksum (~35×, the library's biggest win) and
identified by `sha256`.

```mbt check
///|
test "readme: repeated content deduplicates" {
  let data = repeat(rnd(256, 3), 8) // eight identical 256-byte blocks
  let r = @dedup.dedup(data, 32, 0x3F, 256)
  @test.assert_eq(r.unique_count < r.bounds.length(), true)
}
```

`chunk` returns content-defined `(start, len)` boundaries; `dedup` additionally
collapses identical chunks (`sequence[i]` maps chunk `i` to its representative);
`digest` gives a chunk's SHA-256 identity.
