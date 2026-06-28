// Benchmark-only package comparing Yu-zh/jq against other MoonBit jq impls.

///|
pub fn sample_json() -> String {
  "{\"id\":1234567,\"name\":\"Alice Smith\",\"email\":\"alice@example.com\",\"age\":30,\"active\":true,\"country\":\"US\",\"score\":98,\"tags\":[\"a\",\"b\",\"c\"],\"bio\":\"a longer field to add some realistic bytes to scan past\"}"
}

///|
/// A larger (~1.3 KB) flat object; the queried field `score` sits at the end.
pub fn sample_json_big() -> String {
  let sb = StringBuilder::new()
  sb.write_string("{")
  for i in 0..<60 {
    sb.write_string("\"k")
    sb.write_string(i.to_string())
    sb.write_string("\":\"value_string_number_")
    sb.write_string(i.to_string())
    sb.write_string("\",")
  }
  sb.write_string("\"score\":98}")
  sb.to_string()
}
