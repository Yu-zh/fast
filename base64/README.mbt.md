# `Yu-zh/fast/base64`

Standard (RFC 4648) base64 `encode` / `decode` over `FixedArray[Byte]`,
following the SIMD approach of Muła & Lemire. Encoding processes 12 input
bytes into 16 characters per step, splitting the 6-bit fields with shifts
blended by `v128_bitselect` (a stand-in for the `mulhi`/`mullo` that `v128`
does not expose). Decoding processes 16 characters into 12 bytes using a
perfect-hash classifier (high nibble → bucket) for ASCII→sextet plus a
`dot`-based bit packer; it accepts input with or without `=` padding and
returns `None` for invalid characters or lengths. `encode_url` / `decode_url`
provide the URL-safe variant (RFC 4648 §5: `-`/`_`, no padding).

```mbt check
///|
test "readme: base64" {
  let bytes : FixedArray[Byte] = [b'f', b'o', b'o', b'b', b'a', b'r']
  let encoded = @base64.encode(bytes)
  @test.assert_eq(encoded, [b'Z', b'm', b'9', b'v', b'Y', b'm', b'F', b'y'])
  @test.assert_eq(@base64.decode(encoded), Some(bytes))
}
```
