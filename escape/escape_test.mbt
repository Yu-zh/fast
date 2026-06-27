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
fn to_arr(fa : FixedArray[Byte]) -> Array[Byte] {
  let a = []
  for i in 0..<fa.length() {
    a.push(fa[i])
  }
  a
}

///|
fn html_ref(bytes : FixedArray[Byte]) -> Array[Byte] {
  let out = []
  for i in 0..<bytes.length() {
    let b = bytes[i]
    let rep = if b == b'&' {
      b"&amp;"
    } else if b == b'<' {
      b"&lt;"
    } else if b == b'>' {
      b"&gt;"
    } else if b == b'"' {
      b"&quot;"
    } else if b == b'\'' {
      b"&#39;"
    } else {
      b""
    }
    if rep.length() == 0 {
      out.push(b)
    } else {
      for k in 0..<rep.length() {
        out.push(rep[k])
      }
    }
  }
  out
}

///|
fn url_ref(bytes : FixedArray[Byte]) -> Array[Byte] {
  let out = []
  let hex = b"0123456789ABCDEF"
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if (b >= b'A' && b <= b'Z') ||
      (b >= b'a' && b <= b'z') ||
      (b >= b'0' && b <= b'9') ||
      b == b'-' ||
      b == b'_' ||
      b == b'.' ||
      b == b'~' {
      out.push(b)
    } else {
      out.push(b'%')
      out.push(hex[b.to_int() >> 4])
      out.push(hex[b.to_int() & 0x0f])
    }
  }
  out
}

///|
test "html_escape known cases" {
  @test.assert_eq(
    to_arr(@escape.html_escape(of(b"<a href=\"x\">Tom & 'Jerry'</a>"))),
    to_arr(
      of(b"&lt;a href=&quot;x&quot;&gt;Tom &amp; &#39;Jerry&#39;&lt;/a&gt;"),
    ),
  )
  @test.assert_eq(
    to_arr(@escape.html_escape(of(b"no specials here"))),
    to_arr(of(b"no specials here")),
  )
  @test.assert_eq(to_arr(@escape.html_escape(of(b""))), to_arr(of(b"")))
}

///|
test "url_encode known cases" {
  @test.assert_eq(
    to_arr(@escape.url_encode(of(b"name=John Doe&x=1"))),
    to_arr(of(b"name%3DJohn%20Doe%26x%3D1")),
  )
  @test.assert_eq(
    to_arr(@escape.url_encode(of(b"AZaz09-_.~"))),
    to_arr(of(b"AZaz09-_.~")),
  )
  @test.assert_eq(to_arr(@escape.url_encode(of(b"/"))), to_arr(of(b"%2F")))
}

///|
test "html_escape matches reference across the byte range" {
  let bytes : FixedArray[Byte] = FixedArray::make(256 + 4, 0)
  for i in 0..<256 {
    bytes[i] = i.to_byte()
  }
  bytes[256] = b'&'
  bytes[257] = b'<'
  bytes[258] = b'"'
  bytes[259] = b'\''
  @test.assert_eq(to_arr(@escape.html_escape(bytes)), html_ref(bytes))
}

///|
test "url_encode matches reference across the byte range" {
  let bytes : FixedArray[Byte] = FixedArray::make(256 + 3, 0)
  for i in 0..<256 {
    bytes[i] = i.to_byte()
  }
  bytes[256] = b' '
  bytes[257] = b'%'
  bytes[258] = b'a'
  @test.assert_eq(to_arr(@escape.url_encode(bytes)), url_ref(bytes))
}

///|
test "escaping a 16-aligned all-special block" {
  // a full SIMD block of specials, exercising the non-fast path end to end
  @test.assert_eq(
    to_arr(@escape.html_escape(of(b"<<<<<<<<<<<<<<<<"))),
    to_arr(
      of(b"&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;"),
    ),
  )
  @test.assert_eq(
    to_arr(@escape.url_encode(of(b"################"))),
    to_arr(of(b"%23%23%23%23%23%23%23%23%23%23%23%23%23%23%23%23")),
  )
}
