# `Yu-zh/search`

A grep-like literal text search built on [`Yu-zh/fast`](../../). Matches are
found by the SIMD substring search (`memmem.find`, ~20× scalar) and mapped to
line numbers with SIMD newline scanning (`memchr`).

```mbt check
///|
test "readme: find matching log lines" {
  let log = of(b"ok\nERROR disk full\nok\nERROR oom\n")
  let hits = @search.search_lines(log, of(b"ERROR"))
  @test.assert_eq(hits.length(), 2)
  @test.assert_eq(hits[0].line, 2)
  @test.assert_eq(hits[0].text(log), of(b"ERROR disk full"))
}
```

`find_all` returns every match offset and `count` the total; `search_lines`
gives the distinct matching lines with 1-based line numbers.
