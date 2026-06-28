# `Yu-zh/fast/base32`

Standard base32 (RFC 4648) `encode` / `decode` over `FixedArray[Byte]`.
Encoding maps 5-bit indices to the alphabet with two `i8x16_swizzle` tables
(the alphabet has 32 entries, so a low/high pair), and decoding validates the
alphabet 16 bytes at a time. Unlike base64's clean 6-bits-from-3-bytes split,
base32's 5-bit fields straddle bytes irregularly and don't map onto v128's
lane-uniform shifts, so the bit (un)packing itself is scalar.

```mbt check
///|
test "readme: base32" {
  let data : FixedArray[Byte] = [b'f', b'o', b'o']
  let encoded = @base32.encode(data)
  @test.assert_eq(encoded, [b'M', b'Z', b'X', b'W', b'6', b'=', b'=', b'='])
  @test.assert_eq(@base32.decode(encoded), Some(data))
}
```
