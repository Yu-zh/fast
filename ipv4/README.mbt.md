# `Yu-zh/fast/ipv4`

IPv4 dotted-quad `parse` and `format` over `FixedArray[Byte]`. The whole
address (at most 15 bytes) is loaded into one vector; `i8x16_bitmask` yields
the dot and digit position masks in one shot, the structure is validated
against them, and the three dot offsets are recovered with `ctz`. Octet values
(at most three digits each) are accumulated scalar. `parse` rejects out-of-range
octets, leading zeros, and malformed input.

```mbt check
///|
test "readme: ipv4" {
  let s : FixedArray[Byte] = [
    b'1', b'9', b'2', b'.', b'1', b'6', b'8', b'.', b'1', b'.', b'1',
  ]
  @test.assert_eq(@ipv4.parse(s), Some(0xC0A80101U))
  @test.assert_eq(@ipv4.format(0xC0A80101U), s)
}
```
