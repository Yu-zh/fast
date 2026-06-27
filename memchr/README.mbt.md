# `Yu-zh/fast/memchr`

SIMD single-byte search over `FixedArray[Byte]`. `find_byte`,
`find_last_byte`, and `count_byte` broadcast the needle with `i8x16_splat` and
scan 16 bytes per step using `i8x16_eq` + `i8x16_bitmask`, locating matches
with `ctz` / `clz` / `popcnt` on the resulting mask.

```mbt check
///|
test "readme: memchr" {
  let bytes : FixedArray[Byte] = [b'a', b'b', b'c', b'a', b'b', b'c']
  @test.assert_eq(@memchr.find_byte(bytes, b'c'), Some(2))
  @test.assert_eq(@memchr.find_last_byte(bytes, b'a'), Some(3))
  @test.assert_eq(@memchr.count_byte(bytes, b'b'), 2)
}
```
