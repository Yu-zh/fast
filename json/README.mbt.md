# `Yu-zh/fast/json`

This package is a MoonBit experiment inspired by
[simdjson](https://github.com/simdjson/simdjson). It mirrors the broad
two-stage shape: stage 1 scans structural and pseudo-structural JSON tokens
outside strings, then stage 2 parses from that token index into MoonBit's
built-in `Json` value.

This is not a full simdjson port. It does not implement the C++ On-Demand API,
runtime CPU dispatch, document streams, or fully vectorized structural scanning
yet. The parser core is byte-oriented over UTF-8 `BytesView`; `String` APIs are
convenience wrappers. On native/wasm linear-memory targets, stage 1 uses
`v128_load` from the backing bytes for string scanning and structural/whitespace
runs.

```mbt check
///|
test "parse JSON bytes" {
  let input : Bytes = b"{ \"a\" : [1, true, null] }"
  let value = @json.parse_bytes(input[:])
  inspect(value.stringify(), content="{\"a\":[1,true,null]}")
}
```

```mbt check
///|
test "parse JSON string" {
  let value = @json.parse("{ \"a\" : [1, true, null] }")
  inspect(value.stringify(), content="{\"a\":[1,true,null]}")
}
```

```mbt check
///|
test "minify JSON" {
  inspect(
    @json.minify("{ \"message\" : \"hello, json\" }"),
    content="{\"message\":\"hello, json\"}",
  )
}
```
