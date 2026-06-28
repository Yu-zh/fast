# `Yu-zh/fast/utf8`

SIMD UTF-8 validation and UTF-8 ⇆ UTF-16LE transcoding over
`FixedArray[Byte]`. `validate` / `validate_utf16le` check well-formedness in
SIMD strides; `convert_utf8_to_utf16le` and `convert_utf16le_to_utf8`
transcode, returning `None` on malformed input; and the `*_length_*` helpers
compute exact output sizes so callers can pre-allocate. `count_codepoints`
counts codepoints via a `popcnt` of non-continuation bytes, and
`latin1_to_utf8` / `utf8_to_latin1` transcode ISO-8859-1.

```mbt check
///|
test "readme: utf8" {
  // "Aé" encodes as 0x41 0xC3 0xA9 in UTF-8
  let valid : FixedArray[Byte] = [0x41, 0xC3, 0xA9]
  @test.assert_eq(@utf8.validate(valid), true)
  // a lone continuation byte is invalid
  let invalid : FixedArray[Byte] = [0xC3, 0x28]
  @test.assert_eq(@utf8.validate(invalid), false)
}
```
