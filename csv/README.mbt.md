# `Yu-zh/fast/csv`

SIMD CSV (RFC 4180) structural scanning over `FixedArray[Byte]`, the simdjson
"stage 1" idea applied to CSV. Per 64-byte stride it classifies delimiter,
newline, and quote bytes into bit masks, then a quote-parity prefix-XOR marks
quoted-field interiors — so separators inside quotes are ignored, and a doubled
`""` escape is handled for free (it toggles the parity twice).
`unquoted_positions` returns the offsets of the unquoted separators;
`split_records` builds rows of raw `(start, end)` field ranges. Both take an
optional `delimiter?` (default `,`) and assume input well formed per RFC 4180.

```mbt check
///|
test "readme: csv" {
  // delimiter at index 1, record separator (newline) at index 3
  let doc : FixedArray[Byte] = [b'a', b',', b'b', b'\n', b'c']
  @test.assert_eq(@csv.unquoted_positions(doc), Some([1, 3]))
}
```
