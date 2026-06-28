# `Yu-zh/fast/adler32`

SIMD Adler-32 checksum (RFC 1950) over `FixedArray[Byte]`. Per 16-byte chunk
the two running sums update as `s2 += 16*s1 + sum_j (16-j)*b[j]` and
`s1 += sum_j b[j]`; the byte sum uses `extadd_pairwise` widening adds and the
position-weighted sum uses `i32x4_dot_i16x8_s` (madd). Sums are reduced mod
65521 every 5552 bytes (zlib's NMAX) to avoid 32-bit overflow.

```mbt check
///|
test "readme: adler32" {
  let data : FixedArray[Byte] = [b'a', b'b', b'c']
  @test.assert_eq(@adler32.checksum(data), 0x024D0127U)
}
```
