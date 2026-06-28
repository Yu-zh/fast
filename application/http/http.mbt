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

// A minimal HTTP/1.x request parser. The structure is found by SIMD byte
// scanning from `Yu-zh/fast`: `memchr.find_byte` locates CR line breaks, the
// request-line spaces, and each header colon; `ascii.eq_ignore_case` does
// case-insensitive header lookup. It parses the request line and headers into
// byte-slice views — no allocation beyond the slices themselves.

///|
fn slice(d : FixedArray[Byte], start : Int, end : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(end - start, 0)
  for i in 0..<(end - start) {
    out[i] = d[start + i]
  }
  out
}

///|
/// A parsed request line plus headers.
pub struct Request {
  verb : FixedArray[Byte]
  path : FixedArray[Byte]
  version : FixedArray[Byte]
  headers : Array[(FixedArray[Byte], FixedArray[Byte])]
}

///|
/// Parses an HTTP request: `METHOD SP path SP version CRLF (name: value CRLF)* CRLF`.
/// Returns `None` if the request line is malformed.
pub fn parse(data : FixedArray[Byte]) -> Request? {
  let n = data.length()
  let eol = match @memchr.find_byte(data, b'\r') {
    Some(x) => x
    None => return None
  }
  let sp1 = match @memchr.find_byte(data, b' ') {
    Some(x) => x
    None => return None
  }
  if sp1 >= eol {
    return None
  }
  let verb = slice(data, 0, sp1)
  let sp2 = match @memchr.find_byte(data, b' ', from=sp1 + 1) {
    Some(x) => x
    None => return None
  }
  if sp2 >= eol {
    return None
  }
  let path = slice(data, sp1 + 1, sp2)
  let version = slice(data, sp2 + 1, eol)
  let headers : Array[(FixedArray[Byte], FixedArray[Byte])] = []
  let mut pos = eol + 2 // skip CRLF
  while pos < n {
    let le = match @memchr.find_byte(data, b'\r', from=pos) {
      Some(x) => x
      None => n
    }
    if le == pos {
      break // empty line: end of headers
    }
    match @memchr.find_byte(data, b':', from=pos) {
      Some(c) =>
        if c < le {
          let name = slice(data, pos, c)
          let mut vs = c + 1
          while vs < le && data[vs] == b' ' {
            vs = vs + 1
          }
          headers.push((name, slice(data, vs, le)))
        }
      None => ()
    }
    pos = le + 2
  }
  Some(Request::{ verb, path, version, headers })
}

///|
/// Looks up a header value by name, case-insensitively (the first match).
pub fn Request::header(
  self : Request,
  name : FixedArray[Byte],
) -> FixedArray[Byte]? {
  for h in self.headers {
    if @ascii.eq_ignore_case(h.0, name) {
      return Some(h.1)
    }
  }
  None
}
