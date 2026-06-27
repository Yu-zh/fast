# `Yu-zh/fast/hex`

SIMD lowercase hexadecimal `encode` / `decode` over `FixedArray[Byte]`.
Encoding maps each nibble to its ASCII digit with an `i8x16_swizzle` table and
interleaves the high/low digits with `i8x16_shuffle`; decoding validates with
range checks, folds case, and packs the nibble pairs back into bytes.
`decode` returns `None` on an odd length or any non-hex byte.

```mbt check
///|
test "readme: hex" {
  let bytes : FixedArray[Byte] = [0xde, 0xad, 0xbe, 0xef]
  let encoded = @hex.encode(bytes)
  @test.assert_eq(encoded, [b'd', b'e', b'a', b'd', b'b', b'e', b'e', b'f'])
  @test.assert_eq(@hex.decode(encoded), Some(bytes))
}
```
