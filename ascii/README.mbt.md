# `Yu-zh/fast/ascii`

SIMD ASCII helpers over `FixedArray[Byte]`. `all_ascii` and `find_non_ascii`
scan 16 bytes at a time for the high bit; `skip_whitespace` skips JSON
whitespace (space, tab, CR, LF); `to_lower_ascii` / `to_upper_ascii` change
letter case in place, leaving every other byte untouched; and `eq_ignore_case`
compares two buffers case-insensitively.

```mbt check
///|
test "readme: ascii" {
  let bytes : FixedArray[Byte] = [b'H', b'i', b'!']
  @test.assert_eq(@ascii.all_ascii(bytes), true)
  let ws : FixedArray[Byte] = [b' ', b'\t', b'a']
  @test.assert_eq(@ascii.skip_whitespace(ws), 2)
  @ascii.to_lower_ascii(bytes)
  @test.assert_eq(bytes, [b'h', b'i', b'!'])
  @test.assert_eq(@ascii.eq_ignore_case([b'H', b'I'], [b'h', b'i']), true)
}
```
