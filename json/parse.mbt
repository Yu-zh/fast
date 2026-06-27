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

// Stage 2: recursive descent over the structural marks produced by
// `structural_indices`, building a `Json` document. The SIMD stage already
// separated structure from string contents, so this walk never rescans
// document bytes except inside string and number tokens.

///|
pub(all) suberror ParseError {
  ParseError(String)
} derive(@debug.Debug)

///|
priv struct Parser {
  bytes : FixedArray[Byte]
  indices : Array[Int]
  mut pos : Int
}

///|
/// Parses a UTF-8 encoded JSON document: validates UTF-8, runs the SIMD
/// structural scan (stage 1), then builds the document from the marks
/// (stage 2). Mirrors `@json.parse` semantics, but over bytes instead of a
/// UTF-16 string.
pub fn parse(bytes : FixedArray[Byte]) -> Json raise ParseError {
  if !@utf8.validate(bytes) {
    raise ParseError("invalid UTF-8")
  }
  guard structural_indices(bytes) is Some(indices) else {
    raise ParseError("unclosed string")
  }
  let p = Parser::{ bytes, indices, pos: 0 }
  let value = p.value()
  if p.pos < p.indices.length() {
    raise ParseError(
      "unexpected trailing content at offset \{p.indices[p.pos]}",
    )
  }
  value
}

///|
fn Parser::next_mark(self : Parser) -> Int raise ParseError {
  guard self.pos < self.indices.length() else {
    raise ParseError("unexpected end of input")
  }
  self.indices[self.pos]
}

///|
fn Parser::value(self : Parser) -> Json raise ParseError {
  let mark = self.next_mark()
  self.pos = self.pos + 1
  let b = self.bytes[mark]
  if b == b'{' {
    self.object()
  } else if b == b'[' {
    self.array()
  } else if b == b'"' {
    Json::string(self.string_at(mark))
  } else if b == b't' ||
    b == b'f' ||
    b == b'n' ||
    b == b'-' ||
    (b >= b'0' && b <= b'9') {
    self.scalar_at(mark)
  } else {
    raise ParseError("unexpected character at offset \{mark}")
  }
}

///|
fn Parser::object(self : Parser) -> Json raise ParseError {
  let map : Map[String, Json] = Map([])
  if self.bytes[self.next_mark()] == b'}' {
    self.pos = self.pos + 1
    return Json::object(map)
  }
  while true {
    let key_mark = self.next_mark()
    guard self.bytes[key_mark] == b'"' else {
      raise ParseError("expected string key at offset \{key_mark}")
    }
    self.pos = self.pos + 1
    let key = self.string_at(key_mark)
    let colon_mark = self.next_mark()
    guard self.bytes[colon_mark] == b':' else {
      raise ParseError("expected ':' at offset \{colon_mark}")
    }
    self.pos = self.pos + 1
    map[key] = self.value()
    let sep_mark = self.next_mark()
    let sep = self.bytes[sep_mark]
    self.pos = self.pos + 1
    if sep == b'}' {
      break
    }
    guard sep == b',' else {
      raise ParseError("expected ',' or '}' at offset \{sep_mark}")
    }
  }
  Json::object(map)
}

///|
fn Parser::array(self : Parser) -> Json raise ParseError {
  let items : Array[Json] = []
  if self.bytes[self.next_mark()] == b']' {
    self.pos = self.pos + 1
    return Json::array(items)
  }
  while true {
    items.push(self.value())
    let sep_mark = self.next_mark()
    let sep = self.bytes[sep_mark]
    self.pos = self.pos + 1
    if sep == b']' {
      break
    }
    guard sep == b',' else {
      raise ParseError("expected ',' or ']' at offset \{sep_mark}")
    }
  }
  Json::array(items)
}

///|
fn Parser::hex4(self : Parser, at : Int) -> Int raise ParseError {
  guard at + 4 <= self.bytes.length() else {
    raise ParseError("truncated unicode escape at offset \{at}")
  }
  let mut code = 0
  for k in 0..<4 {
    let b = self.bytes[at + k]
    let digit = if b >= b'0' && b <= b'9' {
      (b - b'0').to_int()
    } else {
      let folded = b | 0x20
      if folded >= b'a' && folded <= b'f' {
        (folded - b'a').to_int() + 10
      } else {
        raise ParseError("invalid unicode escape at offset \{at}")
      }
    }
    code = code * 16 + digit
  }
  code
}

///|
/// Decodes the string whose opening quote is at `open`. The bytes are
/// already known to be valid UTF-8 and the closing quote is known to
/// exist, so multi-byte sequences decode unchecked; escapes and control
/// characters still need checking. Each `\uXXXX` is written as a raw
/// UTF-16 code unit (as `@json.parse` does), so surrogate pairs written as
/// two escapes combine naturally.
fn Parser::string_at(self : Parser, open : Int) -> String raise ParseError {
  let bytes = self.bytes
  let len = bytes.length()
  let buf = StringBuilder::new()
  let mut j = open + 1
  while true {
    guard j < len else { raise ParseError("unterminated string") }
    let b = bytes[j]
    if b == b'"' {
      break
    }
    if b == b'\\' {
      guard j + 1 < len else { raise ParseError("unterminated string") }
      let e = bytes[j + 1]
      if e == b'u' {
        buf.write_char(self.hex4(j + 2).unsafe_to_char())
        j = j + 6
      } else {
        let c = if e == b'"' {
          '"'
        } else if e == b'\\' {
          '\\'
        } else if e == b'/' {
          '/'
        } else if e == b'b' {
          (8).unsafe_to_char()
        } else if e == b'f' {
          (12).unsafe_to_char()
        } else if e == b'n' {
          '\n'
        } else if e == b'r' {
          '\r'
        } else if e == b't' {
          '\t'
        } else {
          raise ParseError("invalid escape at offset \{j}")
        }
        buf.write_char(c)
        j = j + 2
      }
    } else if b < 0x20 {
      raise ParseError("control character in string at offset \{j}")
    } else if b < 0x80 {
      buf.write_char(b.to_int().unsafe_to_char())
      j = j + 1
    } else if b < 0xe0 {
      let cp = ((b.to_int() & 0x1f) << 6) | (bytes[j + 1].to_int() & 0x3f)
      buf.write_char(cp.unsafe_to_char())
      j = j + 2
    } else if b < 0xf0 {
      let cp = ((b.to_int() & 0x0f) << 12) |
        ((bytes[j + 1].to_int() & 0x3f) << 6) |
        (bytes[j + 2].to_int() & 0x3f)
      buf.write_char(cp.unsafe_to_char())
      j = j + 3
    } else {
      let cp = ((b.to_int() & 0x07) << 18) |
        ((bytes[j + 1].to_int() & 0x3f) << 12) |
        ((bytes[j + 2].to_int() & 0x3f) << 6) |
        (bytes[j + 3].to_int() & 0x3f)
      buf.write_char(cp.unsafe_to_char())
      j = j + 4
    }
  }
  buf.to_string()
}

///|
/// End of the scalar token starting at `mark`: up to the next structural
/// mark (or end of input), with trailing whitespace trimmed.
fn Parser::token_end(self : Parser, mark : Int) -> Int {
  let mut end = if self.pos < self.indices.length() {
    self.indices[self.pos]
  } else {
    self.bytes.length()
  }
  while end > mark {
    let b = self.bytes[end - 1]
    if b == b' ' || b == b'\t' || b == b'\n' || b == b'\r' {
      end = end - 1
    } else {
      break
    }
  }
  end
}

///|
fn Parser::token_is(self : Parser, mark : Int, end : Int, lit : Bytes) -> Bool {
  if end - mark != lit.length() {
    return false
  }
  for k in 0..<lit.length() {
    if self.bytes[mark + k] != lit[k] {
      return false
    }
  }
  true
}

///|
fn Parser::scalar_at(self : Parser, mark : Int) -> Json raise ParseError {
  let end = self.token_end(mark)
  let b = self.bytes[mark]
  if b == b't' {
    guard self.token_is(mark, end, b"true") else {
      raise ParseError("invalid literal at offset \{mark}")
    }
    Json::boolean(true)
  } else if b == b'f' {
    guard self.token_is(mark, end, b"false") else {
      raise ParseError("invalid literal at offset \{mark}")
    }
    Json::boolean(false)
  } else if b == b'n' {
    guard self.token_is(mark, end, b"null") else {
      raise ParseError("invalid literal at offset \{mark}")
    }
    Json::null()
  } else {
    self.number_at(mark, end)
  }
}

///|
/// Powers of ten that are exactly representable as doubles.
let pow10_exact : FixedArray[Double] = [
  1.0e0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9, 1.0e10, 1.0e11,
  1.0e12, 1.0e13, 1.0e14, 1.0e15, 1.0e16, 1.0e17, 1.0e18, 1.0e19, 1.0e20, 1.0e21,
  1.0e22,
]

///|
/// Validates the JSON number grammar `-?(0|[1-9][0-9]*)(\.[0-9]+)?
/// ([eE][+-]?[0-9]+)?` over the token, then converts. When the mantissa
/// fits 15 digits and the decimal exponent is within ±22, mantissa and
/// power of ten are both exact doubles and one multiply rounds correctly
/// (Clinger's fast path — the same one strconv takes, so results agree
/// with `@json.parse`). Everything else falls back to `parse_double`;
/// out-of-range values become infinities carrying the source text.
fn Parser::number_at(
  self : Parser,
  mark : Int,
  end : Int,
) -> Json raise ParseError {
  let bytes = self.bytes
  let mut i = mark
  let negative = bytes[i] == b'-'
  if negative {
    i = i + 1
  }
  fn bad() -> ParseError {
    ParseError("invalid number at offset \{mark}")
  }

  let mut mantissa = 0UL
  let mut digits = 0
  let mut exp10 = 0
  guard i < end else { raise bad() }
  if bytes[i] == b'0' {
    i = i + 1
    digits = 1
  } else {
    guard bytes[i] >= b'1' && bytes[i] <= b'9' else { raise bad() }
    while i < end && bytes[i] >= b'0' && bytes[i] <= b'9' {
      mantissa = mantissa * 10UL + (bytes[i] - b'0').to_uint64()
      digits = digits + 1
      i = i + 1
    }
  }
  if i < end && bytes[i] == b'.' {
    i = i + 1
    guard i < end && bytes[i] >= b'0' && bytes[i] <= b'9' else { raise bad() }
    while i < end && bytes[i] >= b'0' && bytes[i] <= b'9' {
      mantissa = mantissa * 10UL + (bytes[i] - b'0').to_uint64()
      digits = digits + 1
      exp10 = exp10 - 1
      i = i + 1
    }
  }
  if i < end && (bytes[i] == b'e' || bytes[i] == b'E') {
    i = i + 1
    let mut exp_neg = false
    if i < end && (bytes[i] == b'+' || bytes[i] == b'-') {
      exp_neg = bytes[i] == b'-'
      i = i + 1
    }
    guard i < end && bytes[i] >= b'0' && bytes[i] <= b'9' else { raise bad() }
    let mut exp_val = 0
    while i < end && bytes[i] >= b'0' && bytes[i] <= b'9' {
      if exp_val < 100000 {
        exp_val = exp_val * 10 + (bytes[i] - b'0').to_int()
      }
      i = i + 1
    }
    exp10 = exp10 + (if exp_neg { -exp_val } else { exp_val })
  }
  guard i == end else { raise bad() }
  if digits <= 15 && exp10 >= -22 && exp10 <= 22 {
    let m = mantissa.to_double()
    let abs = if exp10 >= 0 {
      m * pow10_exact[exp10]
    } else {
      m / pow10_exact[-exp10]
    }
    return Json::number(if negative { -abs } else { abs })
  }
  // slow path: hand the original text to strconv
  let buf = StringBuilder::new()
  for k in mark..<end {
    buf.write_char(bytes[k].to_int().unsafe_to_char())
  }
  let text = buf.to_string()
  Json::number(@string.parse_double(text)) catch {
    _ =>
      if negative {
        Json::number(@double.neg_infinity, repr=text)
      } else {
        Json::number(@double.infinity, repr=text)
      }
  }
}
