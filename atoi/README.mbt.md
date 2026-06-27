# `Yu-zh/fast/atoi`

SIMD decimal integer parsing over `FixedArray[Byte]`. `parse_uint64` and
`parse_int64` validate the digits 16 bytes at a time, then fold eight digits
per step into a single value with the multiply-add chain of Lemire ("Quickly
parsing eight digits"), combining eight-digit groups with checked 64-bit
arithmetic. `parse_int64` accepts an optional leading `+`/`-`. Both return
`None` on an empty array, any non-digit byte, or an out-of-range value.

```mbt check
///|
test "readme: atoi" {
  let digits : FixedArray[Byte] = [b'1', b'2', b'3', b'4', b'5']
  @test.assert_eq(@atoi.parse_uint64(digits), Some(12345UL))
  let signed : FixedArray[Byte] = [b'-', b'4', b'2']
  @test.assert_eq(@atoi.parse_int64(signed), Some(-42L))
  let bad : FixedArray[Byte] = [b'1', b'x']
  @test.assert_eq(@atoi.parse_uint64(bad), None)
}
```
