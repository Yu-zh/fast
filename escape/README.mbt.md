# `Yu-zh/fast/escape`

SIMD web escaping over `FixedArray[Byte]`. `html_escape` escapes the five HTML
special characters (`& < > " '`); `url_encode` percent-encodes everything
outside the RFC 3986 unreserved set `[A-Za-z0-9-._~]`. Both SIMD-scan each
16-byte chunk for characters needing escaping and copy chunks that need none
verbatim, computing the exact output length in a first pass so the result
buffer is sized precisely.

```mbt check
///|
test "readme: escape" {
  let html : FixedArray[Byte] = [b'a', b'<', b'b']
  @test.assert_eq(@escape.html_escape(html), [
    b'a', b'&', b'l', b't', b';', b'b',
  ])
  let url : FixedArray[Byte] = [b'a', b' ', b'b']
  @test.assert_eq(@escape.url_encode(url), [b'a', b'%', b'2', b'0', b'b'])
}
```
