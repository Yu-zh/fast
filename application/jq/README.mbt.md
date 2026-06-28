# `Yu-zh/jq`

A small NDJSON (JSON-lines) query tool built on [`Yu-zh/fast`](../../). Lines
are split with SIMD `memchr`, a substring filter uses SIMD `memmem`, and
`minify` reuses the SIMD JSON minifier. `field` pulls a top-level value out of a
flat JSON object (the usual log-line shape).

```mbt check
///|
test "readme: filter and extract from log lines" {
  let logs = of(
    b"{\"level\":\"info\",\"msg\":\"ok\"}\n{\"level\":\"error\",\"msg\":\"disk full\"}",
  )
  let errors = @jq.select_contains(logs, of(b"\"error\""))
  @test.assert_eq(errors.length(), 1)
  @test.assert_eq(@jq.field(errors[0], of(b"msg")), Some(of(b"disk full")))
}
```

`lines` splits NDJSON into byte ranges; `select_contains` keeps lines matching a
substring; `field` returns a top-level value (quotes stripped for strings).
