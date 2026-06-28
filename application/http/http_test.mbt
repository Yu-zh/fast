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
fn of(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  for i in 0..<s.length() {
    out[i] = s[i]
  }
  out
}

///|
test "parses request line and headers" {
  let req = @http.parse(
    of(
      b"GET /index.html?q=1 HTTP/1.1\r\nHost: example.com\r\nAccept: text/html\r\n\r\n",
    ),
  ).unwrap()
  @test.assert_eq(req.verb, of(b"GET"))
  @test.assert_eq(req.path, of(b"/index.html?q=1"))
  @test.assert_eq(req.version, of(b"HTTP/1.1"))
  @test.assert_eq(req.headers.length(), 2)
}

///|
test "header lookup is case-insensitive" {
  let req = @http.parse(
    of(
      b"POST /api HTTP/1.1\r\nContent-Type: application/json\r\nHost: h\r\n\r\n",
    ),
  ).unwrap()
  @test.assert_eq(
    req.header(of(b"content-type")),
    Some(of(b"application/json")),
  )
  @test.assert_eq(req.header(of(b"HOST")), Some(of(b"h")))
  @test.assert_eq(req.header(of(b"missing")), None)
}

///|
test "no trailing CRLF still parses available headers" {
  let req = @http.parse(of(b"GET / HTTP/1.0\r\nHost: x")).unwrap()
  @test.assert_eq(req.verb, of(b"GET"))
  @test.assert_eq(req.header(of(b"host")), Some(of(b"x")))
}

///|
test "malformed request line is rejected" {
  @test.assert_eq(@http.parse(of(b"GARBAGE-NO-CRLF")) is None, true)
}
