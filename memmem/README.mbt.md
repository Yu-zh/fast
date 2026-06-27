# `Yu-zh/fast/memmem`

SIMD substring search over `FixedArray[Byte]` — the multi-byte generalization
of `memchr`, the "generic SIMD" approach used by Rust's `memchr::memmem` and
Go's `bytes.Index`. It broadcasts the needle's first and last byte, ANDs their
per-window equality masks to find candidate offsets, then verifies each
candidate with a full comparison. Provides `find` (with `from?`), `find_last`,
`count` (non-overlapping), and `contains`.

```mbt check
///|
test "readme: memmem" {
  let haystack : FixedArray[Byte] = [b't', b'h', b'e', b' ', b'c', b'a', b't']
  let needle : FixedArray[Byte] = [b'c', b'a', b't']
  @test.assert_eq(@memmem.find(haystack, needle), Some(4))
  @test.assert_eq(@memmem.contains(haystack, needle), true)
}
```
