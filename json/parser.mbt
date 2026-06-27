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
let default_max_nesting_depth : Int = 1024

///|
let key_cache_limit : Int = 64

///|
let max_cached_key_bytes : Int = 32

///|
priv struct Parser {
  input : JsonInput
  tokens : TokenTape
  key_cache : Map[Bytes, String]
  max_depth : Int
  mut pos : Int
}

///|
pub fn parse(input : String) -> Json raise ParseError {
  parse_with_limit(input, max_nesting_depth=default_max_nesting_depth)
}

///|
pub fn parse_with_limit(
  input : String,
  max_nesting_depth~ : Int,
) -> Json raise ParseError {
  let bytes = @utf8.encode(input[:])
  parse_bytes_with_limit(bytes[:], max_nesting_depth~)
}

///|
pub fn parse_bytes(input : BytesView) -> Json raise ParseError {
  parse_bytes_with_limit(input, max_nesting_depth=default_max_nesting_depth)
}

///|
pub fn parse_bytes_with_limit(
  input : BytesView,
  max_nesting_depth~ : Int,
) -> Json raise ParseError {
  parse_input(JsonInput::from_view(input), max_nesting_depth~)
}

///|
fn parse_input(
  input : JsonInput,
  max_nesting_depth~ : Int,
) -> Json raise ParseError {
  let tokens = scan_token_tape(input)
  parse_tokens(input, tokens, max_nesting_depth~)
}

///|
fn parse_tokens(
  input : JsonInput,
  tokens : TokenTape,
  max_nesting_depth~ : Int,
) -> Json raise ParseError {
  let parser : Parser = {
    input,
    tokens,
    key_cache: Map([]),
    max_depth: max_nesting_depth,
    pos: 0,
  }
  parser.parse_document()
}

///|
pub fn validate(input : String) -> Bool {
  let bytes = @utf8.encode(input[:])
  validate_bytes(bytes[:])
}

///|
pub fn validate_bytes(input : BytesView) -> Bool {
  try parse_bytes(input) catch {
    _ => false
  } noraise {
    _ => true
  }
}

///|
fn Parser::parse_document(self : Parser) -> Json raise ParseError {
  let value = self.parse_value(0)
  if self.pos != self.tokens.length() {
    raise TrailingContent(pos=self.tokens.pos(self.pos))
  }
  value
}

///|
fn Parser::parse_value(self : Parser, depth : Int) -> Json raise ParseError {
  if depth > self.max_depth {
    raise NestingTooDeep(pos=self.current_pos(), limit=self.max_depth)
  }
  let token_index = self.pos
  match self.peek_kind() {
    6 | 11 => {
      self.pos += 1
      Json::string(parse_string_token(self.input, self.tokens, token_index))
    }
    7 => {
      self.pos += 1
      parse_number_token(self.input, self.tokens, token_index)
    }
    0 => {
      self.pos += 1
      self.parse_object(depth + 1)
    }
    2 => {
      self.pos += 1
      self.parse_array(depth + 1)
    }
    8 => {
      self.pos += 1
      Json::boolean(true)
    }
    9 => {
      self.pos += 1
      Json::boolean(false)
    }
    10 => {
      self.pos += 1
      Json::null()
    }
    _ => self.unexpected_token("JSON value")
  }
}

///|
fn Parser::parse_object(self : Parser, depth : Int) -> Json raise ParseError {
  let object : Map[String, Json] = Map([])
  if self.consume_token(token_object_end) {
    return Json::object(object)
  }
  for ;; {
    let key_token = self.expect_string_token("object key string")
    let key = self.parse_key_token(key_token)
    ignore(self.expect_token(token_colon, "':'"))
    let value = self.parse_value(depth)
    object.set(key, value)
    if self.consume_token(token_comma) {
      continue
    }
    if self.consume_token(token_object_end) {
      return Json::object(object)
    }
    return self.unexpected_token("',' or '}'")
  }
}

///|
fn Parser::parse_array(self : Parser, depth : Int) -> Json raise ParseError {
  let values : Array[Json] = []
  if self.consume_token(token_array_end) {
    return Json::array(values)
  }
  for ;; {
    values.push(self.parse_value(depth))
    if self.consume_token(token_comma) {
      continue
    }
    if self.consume_token(token_array_end) {
      return Json::array(values)
    }
    return self.unexpected_token("',' or ']'")
  }
}

///|
fn Parser::parse_key_token(
  self : Parser,
  token_index : Int,
) -> String raise ParseError {
  let content_start = self.tokens.pos(token_index) + 1
  let content_end = self.tokens.end(token_index) - 1
  if self.tokens.kind(token_index) == token_string &&
    content_end - content_start <= max_cached_key_bytes {
    let view = self.input.view(content_start, content_end)
    match self.key_cache.get_from_bytes(view) {
      Some(key) => key
      None => {
        let key = decode_utf8_segment(
          self.input,
          content_start,
          content_end,
          content_start,
        )
        if self.key_cache.length() < key_cache_limit {
          self.key_cache.set(view.to_owned(), key)
        }
        key
      }
    }
  } else {
    parse_string_token(self.input, self.tokens, token_index)
  }
}

///|
fn Parser::is_string_token_at(self : Parser, token_index : Int) -> Bool {
  let kind = self.tokens.kind(token_index)
  kind == token_string || kind == token_string_escaped
}

///|
fn Parser::expect_string_token(
  self : Parser,
  expected : String,
) -> Int raise ParseError {
  let token_index = self.pos
  if self.pos < self.tokens.length() && self.is_string_token_at(token_index) {
    self.pos += 1
    token_index
  } else if self.pos < self.tokens.length() {
    let pos = self.tokens.pos(token_index)
    raise UnexpectedChar(pos~, expected~, found=self.input.at(pos))
  } else {
    raise UnexpectedEof(pos=self.input.len)
  }
}

///|
fn Parser::peek_kind(self : Parser) -> Int raise ParseError {
  if self.pos < self.tokens.length() {
    self.tokens.kind(self.pos)
  } else {
    raise UnexpectedEof(pos=self.input.len)
  }
}

///|
fn Parser::consume_token(self : Parser, kind : Int) -> Bool {
  if self.pos < self.tokens.length() && self.tokens.kind(self.pos) == kind {
    self.pos += 1
    true
  } else {
    false
  }
}

///|
fn Parser::expect_token(
  self : Parser,
  kind : Int,
  expected : String,
) -> Int raise ParseError {
  let token_index = self.pos
  if self.peek_kind() == kind {
    self.pos += 1
    token_index
  } else {
    let pos = self.tokens.pos(token_index)
    raise UnexpectedChar(pos~, expected~, found=self.input.at(pos))
  }
}

///|
fn Parser::unexpected_token(
  self : Parser,
  expected : String,
) -> Json raise ParseError {
  if self.pos < self.tokens.length() {
    let pos = self.tokens.pos(self.pos)
    raise UnexpectedChar(pos~, expected~, found=self.input.at(pos))
  } else {
    raise UnexpectedEof(pos=self.input.len)
  }
}

///|
fn Parser::current_pos(self : Parser) -> Int {
  if self.pos < self.tokens.length() {
    self.tokens.pos(self.pos)
  } else {
    self.input.len
  }
}

///|
fn parse_string_token(
  input : JsonInput,
  tokens : TokenTape,
  token_index : Int,
) -> String raise ParseError {
  let content_start = tokens.pos(token_index) + 1
  let content_end = tokens.end(token_index) - 1
  if tokens.kind(token_index) == token_string {
    return decode_utf8_segment(input, content_start, content_end, content_start)
  }
  let builder = StringBuilder(size_hint=content_end - content_start)
  let mut segment_start = content_start
  let mut index = content_start
  while index < content_end {
    if input.at(index) == backslash_byte() {
      if segment_start < index {
        builder.write_string(
          decode_utf8_segment(input, segment_start, index, segment_start),
        )
      }
      let (escaped_ch, next) = parse_escape_char_at(
        input,
        index + 1,
        content_end,
      )
      builder.write_char(escaped_ch)
      index = next
      segment_start = index
    } else {
      index += 1
    }
  }
  if segment_start < content_end {
    builder.write_string(
      decode_utf8_segment(input, segment_start, content_end, segment_start),
    )
  }
  builder.to_string()
}

///|
fn parse_escape_char_at(
  input : JsonInput,
  pos : Int,
  limit : Int,
) -> (Char, Int) raise ParseError {
  if pos >= limit {
    raise UnexpectedEof(pos~)
  }
  let escaped = input.at(pos)
  if escaped == quote_byte() {
    ('"', pos + 1)
  } else if escaped == backslash_byte() {
    ('\\', pos + 1)
  } else if escaped == b'/' {
    ('/', pos + 1)
  } else if escaped == b'b' {
    (ascii_char(8), pos + 1)
  } else if escaped == b'f' {
    (ascii_char(12), pos + 1)
  } else if escaped == b'n' {
    ('\n', pos + 1)
  } else if escaped == b'r' {
    ('\r', pos + 1)
  } else if escaped == b't' {
    ('\t', pos + 1)
  } else if escaped == b'u' {
    if pos + 5 > limit {
      raise UnexpectedEof(pos~)
    }
    let code = parse_hex4(input, pos + 1)
    if code.is_leading_surrogate() {
      let next_slash = pos + 5
      if next_slash + 6 > limit ||
        input.at(next_slash) != backslash_byte() ||
        input.at(next_slash + 1) != b'u' {
        raise InvalidString(pos~, message="missing trailing surrogate escape")
      }
      let low = parse_hex4(input, next_slash + 2)
      if !low.is_trailing_surrogate() {
        raise InvalidString(
          pos=next_slash + 2,
          message="invalid trailing surrogate escape",
        )
      }
      match decode_surrogate_pair(code, low) {
        Some(ch) => (ch, next_slash + 6)
        None => raise InvalidString(pos~, message="invalid unicode scalar")
      }
    } else if code.is_trailing_surrogate() {
      raise InvalidString(
        pos~,
        message="trailing surrogate without leading surrogate",
      )
    } else {
      match code.to_char() {
        Some(ch) => (ch, pos + 5)
        None => raise InvalidString(pos~, message="invalid unicode scalar")
      }
    }
  } else {
    raise InvalidString(pos~, message="invalid escape")
  }
}

///|
fn parse_number_token(
  input : JsonInput,
  tokens : TokenTape,
  token_index : Int,
) -> Json raise ParseError {
  let start = tokens.pos(token_index)
  let end = tokens.end(token_index)
  let parsed = parse_short_integer_number(input, start, end)
  let repr = decode_utf8_segment(input, start, end, start)
  let number = match parsed {
    Some(number) => number
    None =>
      @strconv.from_str(repr[:]) catch {
        _ => raise InvalidNumber(pos=start, lexeme=repr)
      }
  }
  if number.is_inf() || number.is_nan() {
    raise InvalidNumber(pos=start, lexeme=repr)
  }
  Json::number(number, repr~)
}

///|
fn parse_short_integer_number(
  input : JsonInput,
  start : Int,
  end : Int,
) -> Double? {
  let mut index = start
  let mut negative = false
  if input.at(index) == b'-' {
    negative = true
    index += 1
  }
  let mut number = 0.0
  let mut digit_count = 0
  while index < end {
    let ch = input.at(index)
    if !is_digit(ch) {
      return None
    }
    digit_count += 1
    if digit_count > 15 {
      return None
    }
    number = number * 10.0 + (ch.to_int() - 48).to_double()
    index += 1
  }
  if negative {
    Some(-number)
  } else {
    Some(number)
  }
}
