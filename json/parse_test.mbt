// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn to_utf8(s : String) -> FixedArray[Byte] {
  let buf : Array[Byte] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp.to_byte())
    } else if cp < 0x800 {
      buf.push((0xc0 | (cp >> 6)).to_byte())
      buf.push((0x80 | (cp & 0x3f)).to_byte())
    } else if cp < 0x10000 {
      buf.push((0xe0 | (cp >> 12)).to_byte())
      buf.push((0x80 | ((cp >> 6) & 0x3f)).to_byte())
      buf.push((0x80 | (cp & 0x3f)).to_byte())
    } else {
      buf.push((0xf0 | (cp >> 18)).to_byte())
      buf.push((0x80 | ((cp >> 12) & 0x3f)).to_byte())
      buf.push((0x80 | ((cp >> 6) & 0x3f)).to_byte())
      buf.push((0x80 | (cp & 0x3f)).to_byte())
    }
  }
  let out : FixedArray[Byte] = FixedArray::make(buf.length(), 0)
  for i in 0..<buf.length() {
    out[i] = buf[i]
  }
  out
}

///|
test "agrees with @json.parse on valid documents" {
  let docs = [
    "null", "true", "false", "42", "-0.5", "3.14159", "1e10", "-1.25e-3", "0", "\"\"",
    "\"hello\"", "[]", "{}", "[1, 2, 3]", "[[[[1]]]]", "{\"a\": 1, \"b\": [true, null], \"c\": {\"d\": \"e\"}}",
    "  {  \"spaced\" :\t[ 1 ,\n 2 ]  }  ", "{\"a\": 1, \"a\": 2}", // duplicate keys: last one wins
     "\"esc \\\" \\\\ \\/ \\b \\f \\n \\r \\t end\"", "\"\\u0041\\u00e9\\u4f60\"", // A, é, 你 as escapes
     "\"\\ud83c\\udf89\"", // 🎉 as a surrogate pair
     "\"héllo wörld 你好 🎉\"", // raw UTF-8
     "[123456789, 0.000001, 1234.5678e21]", "{\"deep\": [{\"x\": [0, -1, {\"y\": null}]}]}",
  ]
  for doc in docs {
    let got = @json.parse(to_utf8(doc))
    let expected = @corejson.parse(doc)
    @test.assert_eq(got, expected, msg=doc)
  }
}

///|
test "documents larger than one stride" {
  // force string and number tokens across many 64-byte strides
  let buf = StringBuilder::new()
  buf.write_string("[")
  for i in 0..<200 {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string("{\"key_\{i}\": \"value \\\" \{i} 🎉\", \"n\": \{i}.25}")
  }
  buf.write_string("]")
  let doc = buf.to_string()
  @test.assert_eq(@json.parse(to_utf8(doc)), @corejson.parse(doc))
}

///|
test "rejects malformed documents" {
  let bad_docs = [
    "", " ", "[1,]", "{", "[", "[1 2]", "{\"a\" 1}", "{\"a\":}", "{\"a\":1,}", "{a: 1}",
    "tru", "truex", "nul", "+1", "01", "1.", ".5", "1e", "1e+", "-", "[1] 2", "1 2",
    "}", "]", ",", ":", "{\"a\": 1]", "[1}", "\"unclosed", "\"bad escape \\x\"",
    "\"bad hex \\u12g4\"", "\"trunc \\u12", "[\"\\\"]",
  ]
  for doc in bad_docs {
    @test.assert_raise(() => @json.parse(to_utf8(doc)))
  }
  // control character in a string must be rejected
  let ctrl : FixedArray[Byte] = [b'"', b'a', 0x07, b'"']
  @test.assert_raise(() => @json.parse(ctrl))
  // invalid UTF-8 must be rejected before parsing
  let bad_utf8 : FixedArray[Byte] = [b'"', 0xff, b'"']
  @test.assert_raise(() => @json.parse(bad_utf8))
}

///|
test "error agreement with @json.parse" {
  // documents where both parsers should agree on accept/reject
  let docs = [
    "[]", "[1,]", "{\"a\":1}", "{\"a\":1,}", "tru", "1 2", "\"\\u0z00\"", "[true, false]",
    "{\"a\"}", "[,]", "\"ok\"", "nan", "infinity",
  ]
  for doc in docs {
    let ours_ok = try {
      @json.parse(to_utf8(doc)) |> ignore
      true
    } catch {
      _ => false
    }
    let core_ok = try {
      @corejson.parse(doc) |> ignore
      true
    } catch {
      _ => false
    }
    @test.assert_eq(ours_ok, core_ok, msg=doc)
  }
}

///|
test "out-of-range numbers become infinities with repr" {
  let got = @json.parse(to_utf8("[1e999, -1e999]"))
  let expected = @corejson.parse("[1e999, -1e999]")
  @test.assert_eq(got, expected)
}
