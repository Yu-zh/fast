# `Yu-zh/csvq`

A tiny CSV analytics engine built on [`Yu-zh/fast`](../../). Records are split
with the SIMD CSV field scanner (`csv.split_records`, which vectorizes comma /
quote / newline classification); numeric aggregations parse cells with `atoi`.
Non-numeric cells (a header row, blanks) are skipped, so aggregates work without
stripping the header first.

```mbt check
///|
test "readme: aggregate a column" {
  let t = @csvq.parse(of(b"item,qty\napple,3\npear,7\nplum,5\n")).unwrap()
  @test.assert_eq(t.sum_int(1), 15)
  @test.assert_eq(t.max_int(1), Some(7))
  @test.assert_eq(t.mean_int(1), Some(5.0))
}
```

`parse` yields a `Table` of field ranges; `cell` reads a cell, and
`sum_int` / `min_int` / `max_int` / `mean_int` / `count_int` aggregate a column.
