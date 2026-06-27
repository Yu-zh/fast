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
test "parse arrays and scalars" {
  let value = @json.parse("[1,true,false,null,\"x\"]")
  inspect(value.stringify(), content="[1,true,false,null,\"x\"]")
}

///|
test "parse bytes arrays and scalars" {
  let input : Bytes = b"[1,true,false,null,\"x\"]"
  let value = @json.parse_bytes(input[:])
  inspect(value.stringify(), content="[1,true,false,null,\"x\"]")
}

///|
test "parse object fields and escaped strings" {
  let value = @json.parse("{\"n\":-0.25e+2,\"ok\":true,\"s\":\"a\\u0041\\n\"}")
  match value {
    Object(map) => {
      inspect(map.get("n").unwrap().stringify(), content="-0.25e+2")
      inspect(map.get("ok").unwrap().stringify(), content="true")
      inspect(map.get("s").unwrap().stringify(), content="\"aA\\n\"")
    }
    _ => fail("expected object")
  }
}

///|
test "parse and reject UTF-8 bytes" {
  let input = @utf8.encode("{\"s\":\"雪\"}"[:])
  let value = @json.parse_bytes(input[:])
  match value {
    Object(map) => inspect(map.get("s").unwrap().stringify(), content="\"雪\"")
    _ => fail("expected object")
  }
  let invalid = Bytes::from_array([b'"', (255).to_byte(), b'"'])
  @test.assert_eq(@json.validate_bytes(invalid[:]), false)
}

///|
test "minify validates and preserves strings" {
  inspect(
    @json.minify("{ \"a\" : [ 1, true, \" x y \" ] }"),
    content="{\"a\":[1,true,\" x y \"]}",
  )
  let input : Bytes = b"{ \"a\" : [ 1, true, \" x y \" ] }"
  inspect(@json.minify_bytes(input[:]), content="{\"a\":[1,true,\" x y \"]}")
}

///|
test "validate rejects malformed input" {
  @test.assert_eq(@json.validate("{]"), false)
  @test.assert_eq(@json.validate("{\"a\":}"), false)
  @test.assert_eq(@json.validate("\"unterminated"), false)
  @test.assert_eq(@json.validate("[01]"), false)
  @test.assert_eq(@json.validate("1e9999"), false)
  @test.assert_eq(@json.validate("[1,2,3]"), true)
  let valid_bytes : Bytes = b"[1,2,3]"
  let invalid_bytes : Bytes = b"{]"
  @test.assert_eq(@json.validate_bytes(valid_bytes[:]), true)
  @test.assert_eq(@json.validate_bytes(invalid_bytes[:]), false)
}

///|
test "decode unicode surrogate pair escapes" {
  let value = @json.parse("\"\\uD83D\\uDE00\"")
  match value {
    String(text) =>
      @test.assert_eq(text.get_char(0).unwrap().to_uint(), 0x1f600U)
    _ => fail("expected string")
  }
}

///|
test "reject malformed surrogate unicode escapes" {
  try @json.parse("\"\\uD800\"") catch {
    _ => ()
  } noraise {
    _ => fail("expected parse to fail")
  }
  try @json.parse("\"\\uD800\\u0041\"") catch {
    _ => ()
  } noraise {
    _ => fail("expected parse to fail")
  }
}
