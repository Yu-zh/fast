# `Yu-zh/http`

A minimal HTTP/1.x request parser built on [`Yu-zh/fast`](../../). The request
line and headers are located by SIMD byte scanning (`memchr.find_byte` for CR
line breaks, request-line spaces, and header colons); header lookup is
case-insensitive via `ascii.eq_ignore_case`. Fields are byte-slice views.

```mbt check
///|
test "readme: parse a request" {
  let req = @http.parse(of(b"GET /hello HTTP/1.1\r\nHost: example.com\r\n\r\n")).unwrap()
  @test.assert_eq(req.verb, of(b"GET"))
  @test.assert_eq(req.path, of(b"/hello"))
  @test.assert_eq(req.header(of(b"host")), Some(of(b"example.com")))
}
```
