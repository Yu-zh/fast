# `Yu-zh/cidr`

IPv4 CIDR parsing and allowlist matching, built on [`Yu-zh/fast`](../../).
Addresses are parsed with the SIMD `ipv4.parse` (the whole dotted-quad
classified in a single vector); a prefix length becomes a 32-bit mask, so
membership is one masked compare.

```mbt check
///|
test "readme: allowlist matching" {
  let allow = @cidr.Allowlist::of([of(b"10.0.0.0/8"), of(b"192.168.0.0/16")]).unwrap()
  @test.assert_eq(allow.allows_bytes(of(b"10.1.2.3")), true)
  @test.assert_eq(allow.allows_bytes(of(b"192.168.9.9")), true)
  @test.assert_eq(allow.allows_bytes(of(b"8.8.8.8")), false)
}
```

`parse` accepts `"a.b.c.d/n"` or a bare `"a.b.c.d"` (treated as `/32`), and
returns `None` for malformed input.
