# `Yu-zh/fast/json`

This package mirrors the `moonbitlang/core/fast/json` experiment, working over
`FixedArray[Byte]` rather than a UTF-16 string.

- `parse` validates UTF-8, runs a simdjson-style structural-index pass (stage
  1), then descends into MoonBit's built-in `Json` value (stage 2).
- `structural_indices` exposes that stage-1 scan directly: the byte offsets a
  parser must visit (structural characters, string-opening quotes, and the
  first byte of each scalar), all outside string contents.
- `minify` drops insignificant whitespace, reusing the stage-1 in-string mask
  so whitespace inside strings is preserved.
- `escape_string` is the serialization side: it escapes `"`, `\`, and control
  characters, SIMD-scanning for bytes that need escaping and copying the rest
  verbatim.

```mbt check
///|
test "parse JSON bytes" {
  let input : FixedArray[Byte] = [b'[', b'1', b',', b'2', b']']
  let value = @json.parse(input)
  inspect(value.stringify(), content="[1,2]")
}
```

```mbt check
///|
test "minify drops insignificant whitespace" {
  let input : FixedArray[Byte] = [b'[', b'1', b',', b' ', b'2', b']']
  @test.assert_eq(@json.minify(input), Some([b'[', b'1', b',', b'2', b']']))
}
```
