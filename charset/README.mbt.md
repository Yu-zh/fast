# `Yu-zh/fast/charset`

SIMD set-membership over `FixedArray[Byte]` (the simdjson/Hyperscan "lookup"
technique). A byte set compiles to a 16x16 nibble bitmap held in two 16-byte
tables; testing a byte is two `i8x16_swizzle` table lookups, a bit select, and
a power-of-two `swizzle` to build the test bit (no per-lane variable shift
needed). `validate` and `find_invalid` scan 16 bytes per step.

```mbt check
///|
test "readme: charset" {
  let digits : FixedArray[Byte] = [
    b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9',
  ]
  let cs = @charset.Charset::of(digits)
  let ok : FixedArray[Byte] = [b'4', b'2']
  let bad : FixedArray[Byte] = [b'4', b'x', b'2']
  @test.assert_eq(cs.validate(ok), true)
  @test.assert_eq(cs.find_invalid(bad), Some(1))
}
```
