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

// Web escaping kernels. The expensive part of escaping is usually deciding
// that a chunk needs no escaping at all; a SIMD scan answers that for 16
// bytes at once and copies them verbatim, falling back to byte-at-a-time
// emission only for chunks that contain characters needing escapes. Output
// sizes are computed exactly in a first pass.

///|
fn put(out : FixedArray[Byte], pos : Int, s : Bytes) -> Int {
  for k in 0..<s.length() {
    out[pos + k] = s[k]
  }
  pos + s.length()
}

// --- HTML escaping --------------------------------------------------------

///|
fn html_cost(b : Byte) -> Int {
  if b == b'&' {
    5
  } else if b == b'<' || b == b'>' {
    4
  } else if b == b'"' {
    6
  } else if b == b'\'' {
    5
  } else {
    1
  }
}

///|
fn write_html(out : FixedArray[Byte], pos : Int, b : Byte) -> Int {
  if b == b'&' {
    put(out, pos, b"&amp;")
  } else if b == b'<' {
    put(out, pos, b"&lt;")
  } else if b == b'>' {
    put(out, pos, b"&gt;")
  } else if b == b'"' {
    put(out, pos, b"&quot;")
  } else if b == b'\'' {
    put(out, pos, b"&#39;")
  } else {
    out[pos] = b
    pos + 1
  }
}

///|
fn html_special(v : V128) -> V128 {
  @v128.v128_or_(
    @v128.v128_or_(
      @v128.v128_or_(
        @v128.i8x16_eq(v, @v128.i8x16_splat(b'&')),
        @v128.i8x16_eq(v, @v128.i8x16_splat(b'<')),
      ),
      @v128.v128_or_(
        @v128.i8x16_eq(v, @v128.i8x16_splat(b'>')),
        @v128.i8x16_eq(v, @v128.i8x16_splat(b'"')),
      ),
    ),
    @v128.i8x16_eq(v, @v128.i8x16_splat(b'\'')),
  )
}

///|
/// Escapes the five HTML special characters (`& < > " '`) for safe inclusion
/// in element text or double-quoted attribute values. All other bytes,
/// including multi-byte UTF-8, are passed through unchanged.
pub fn html_escape(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let mut total = 0
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(html_special(v)) == 0 {
      total = total + 16
    } else {
      for j in 0..<16 {
        total = total + html_cost(bytes[i + j])
      }
    }
    i = i + 16
  }
  while i < len {
    total = total + html_cost(bytes[i])
    i = i + 1
  }
  let out : FixedArray[Byte] = FixedArray::make(total, 0)
  let mut outpos = 0
  i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(html_special(v)) == 0 {
      for j in 0..<16 {
        out[outpos + j] = bytes[i + j]
      }
      outpos = outpos + 16
    } else {
      for j in 0..<16 {
        outpos = write_html(out, outpos, bytes[i + j])
      }
    }
    i = i + 16
  }
  while i < len {
    outpos = write_html(out, outpos, bytes[i])
    i = i + 1
  }
  out
}

// --- URL percent-encoding -------------------------------------------------

///|
fn is_unreserved(b : Byte) -> Bool {
  (b >= b'A' && b <= b'Z') ||
  (b >= b'a' && b <= b'z') ||
  (b >= b'0' && b <= b'9') ||
  b == b'-' ||
  b == b'_' ||
  b == b'.' ||
  b == b'~'
}

///|
fn hex_upper(n : Int) -> Byte {
  if n < 10 {
    b'0' + n.to_byte()
  } else {
    b'A' + (n - 10).to_byte()
  }
}

///|
fn write_url(out : FixedArray[Byte], pos : Int, b : Byte) -> Int {
  if is_unreserved(b) {
    out[pos] = b
    pos + 1
  } else {
    out[pos] = b'%'
    out[pos + 1] = hex_upper(b.to_int() >> 4)
    out[pos + 2] = hex_upper(b.to_int() & 0x0f)
    pos + 3
  }
}

///|
fn url_unreserved(v : V128) -> V128 {
  let upper = @v128.v128_and_(
    @v128.i8x16_ge_u(v, @v128.i8x16_splat(b'A')),
    @v128.i8x16_le_u(v, @v128.i8x16_splat(b'Z')),
  )
  let lower = @v128.v128_and_(
    @v128.i8x16_ge_u(v, @v128.i8x16_splat(b'a')),
    @v128.i8x16_le_u(v, @v128.i8x16_splat(b'z')),
  )
  let digit = @v128.v128_and_(
    @v128.i8x16_ge_u(v, @v128.i8x16_splat(b'0')),
    @v128.i8x16_le_u(v, @v128.i8x16_splat(b'9')),
  )
  let marks = @v128.v128_or_(
    @v128.v128_or_(
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'-')),
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'_')),
    ),
    @v128.v128_or_(
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'.')),
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'~')),
    ),
  )
  @v128.v128_or_(@v128.v128_or_(upper, lower), @v128.v128_or_(digit, marks))
}

///|
/// Percent-encodes `bytes` per RFC 3986: the unreserved set
/// `[A-Za-z0-9-._~]` is preserved and every other byte becomes `%XX` with
/// uppercase hexadecimal digits.
pub fn url_encode(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let mut total = 0
  let mut i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(url_unreserved(v)) == 0xffff {
      total = total + 16
    } else {
      for j in 0..<16 {
        total = total + (if is_unreserved(bytes[i + j]) { 1 } else { 3 })
      }
    }
    i = i + 16
  }
  while i < len {
    total = total + (if is_unreserved(bytes[i]) { 1 } else { 3 })
    i = i + 1
  }
  let out : FixedArray[Byte] = FixedArray::make(total, 0)
  let mut outpos = 0
  i = 0
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    if @v128.i8x16_bitmask(url_unreserved(v)) == 0xffff {
      for j in 0..<16 {
        out[outpos + j] = bytes[i + j]
      }
      outpos = outpos + 16
    } else {
      for j in 0..<16 {
        outpos = write_url(out, outpos, bytes[i + j])
      }
    }
    i = i + 16
  }
  while i < len {
    outpos = write_url(out, outpos, bytes[i])
    i = i + 1
  }
  out
}
