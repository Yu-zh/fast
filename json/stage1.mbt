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
let true_literal : Bytes = b"true"

///|
let false_literal : Bytes = b"false"

///|
let null_literal : Bytes = b"null"

///|
let simd_lanes : Int = 16

///|
#cfg(any(target="native", target="wasm"))
let simd_lane_mask : Int = 65535

///|
priv struct JsonInput {
  bytes : Bytes
  base : Int
  len : Int
}

///|
fn JsonInput::from_view(input : BytesView) -> JsonInput {
  { bytes: input.data(), base: input.start_offset(), len: input.length() }
}

///|
fn JsonInput::at(self : JsonInput, index : Int) -> Byte {
  self.bytes[self.base + index]
}

///|
fn JsonInput::view(self : JsonInput, start : Int, end : Int) -> BytesView {
  self.bytes[self.base + start:self.base + end]
}

///|
#cfg(any(target="native", target="wasm"))
fn unsafe_fixedarray_from_bytes(bytes : Bytes) -> FixedArray[Byte] = "%identity"

///|
#cfg(any(target="native", target="wasm"))
fn JsonInput::v128_load(self : JsonInput, index : Int) -> V128 {
  @v128.v128_load(unsafe_fixedarray_from_bytes(self.bytes), self.base + index)
}

///|
fn quote_byte() -> Byte {
  b'"'
}

///|
fn backslash_byte() -> Byte {
  b'\\'
}

///|
let token_object_start = 0

///|
let token_object_end = 1

///|
let token_array_start = 2

///|
let token_array_end = 3

///|
let token_colon = 4

///|
let token_comma = 5

///|
let token_string = 6

///|
let token_number = 7

///|
let token_true = 8

///|
let token_false = 9

///|
let token_null = 10

///|
let token_string_escaped = 11

///|
priv struct TokenTape {
  data : Array[Int]
}

///|
fn token_kind_from_code(code : Int) -> TokenKind {
  match code {
    0 => ObjectStart
    1 => ObjectEnd
    2 => ArrayStart
    3 => ArrayEnd
    4 => ColonToken
    5 => CommaToken
    6 => StringToken
    7 => NumberToken
    8 => TrueToken
    9 => FalseToken
    10 => NullToken
    11 => StringToken
    _ => NullToken
  }
}

///|
fn token_code(ch : Byte) -> Int {
  if ch == b'{' {
    token_object_start
  } else if ch == b'}' {
    token_object_end
  } else if ch == b'[' {
    token_array_start
  } else if ch == b']' {
    token_array_end
  } else if ch == b':' {
    token_colon
  } else if ch == b',' {
    token_comma
  } else {
    -1
  }
}

///|
fn TokenTape::new(size_hint : Int) -> TokenTape {
  { data: Array::new(capacity=size_hint * 3) }
}

///|
fn TokenTape::push(self : TokenTape, pos : Int, end : Int, kind : Int) -> Unit {
  self.data.push(pos)
  self.data.push(end)
  self.data.push(kind)
}

///|
fn TokenTape::length(self : TokenTape) -> Int {
  self.data.length() / 3
}

///|
fn TokenTape::pos(self : TokenTape, index : Int) -> Int {
  self.data[index * 3]
}

///|
fn TokenTape::end(self : TokenTape, index : Int) -> Int {
  self.data[index * 3 + 1]
}

///|
fn TokenTape::kind(self : TokenTape, index : Int) -> Int {
  self.data[index * 3 + 2]
}

///|
fn TokenTape::to_tokens(self : TokenTape) -> Array[Token] {
  Array::makei(self.length(), index => {
    pos: self.pos(index),
    end: self.end(index),
    kind: token_kind_from_code(self.kind(index)),
  })
}

///|
#cfg(any(target="native", target="wasm"))
fn byte_mask(lanes : V128, value : Byte) -> Int {
  @v128.i8x16_bitmask(@v128.i8x16_eq(lanes, @v128.i8x16_splat(value)))
}

///|
#cfg(any(target="native", target="wasm"))
fn structural_mask(lanes : V128) -> Int {
  byte_mask(lanes, b'{') |
  byte_mask(lanes, b'}') |
  byte_mask(lanes, b'[') |
  byte_mask(lanes, b']') |
  byte_mask(lanes, b':') |
  byte_mask(lanes, b',')
}

///|
#cfg(any(target="native", target="wasm"))
fn whitespace_mask(lanes : V128) -> Int {
  byte_mask(lanes, b' ') |
  byte_mask(lanes, b'\n') |
  byte_mask(lanes, b'\r') |
  byte_mask(lanes, b'\t')
}

///|
#cfg(any(target="native", target="wasm"))
fn string_event_mask(lanes : V128) -> Int {
  byte_mask(lanes, quote_byte()) |
  byte_mask(lanes, backslash_byte()) |
  @v128.i8x16_bitmask(@v128.i8x16_lt_u(lanes, @v128.i8x16_splat(b' ')))
}

///|
#cfg(any(target="native", target="wasm"))
fn emit_structural_token_block(
  tokens : TokenTape,
  input : JsonInput,
  start : Int,
  mask : Int,
) -> Unit {
  for lane in 0..<simd_lanes {
    if (mask & (1 << lane)) != 0 {
      let pos = start + lane
      tokens.push(pos, pos + 1, token_code(input.at(pos)))
    }
  }
}

///|
#cfg(any(target="native", target="wasm"))
fn scan_simd_token_block(
  input : JsonInput,
  tokens : TokenTape,
  index : Int,
) -> Int? {
  if index + simd_lanes > input.len {
    return None
  }
  let lanes = input.v128_load(index)
  let structural = structural_mask(lanes)
  let whitespace = whitespace_mask(lanes)
  if whitespace == simd_lane_mask {
    Some(index + simd_lanes)
  } else if (structural | whitespace) == simd_lane_mask {
    emit_structural_token_block(tokens, input, index, structural)
    Some(index + simd_lanes)
  } else {
    None
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
fn scan_simd_token_block(
  _input : JsonInput,
  _tokens : TokenTape,
  _index : Int,
) -> Int? {
  None
}

///|
#cfg(any(target="native", target="wasm"))
fn first_string_simd_event(input : JsonInput, index : Int) -> Int? {
  let mask = string_event_mask(input.v128_load(index))
  if mask == 0 {
    None
  } else {
    Some(index + mask.ctz())
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
fn first_string_simd_event(_input : JsonInput, index : Int) -> Int? {
  Some(index)
}

///|
#warnings("-unused_value")
fn token_indexes(input : BytesView) -> Array[Token] raise ParseError {
  scan_token_tape(JsonInput::from_view(input)).to_tokens()
}

///|
fn scan_token_tape(input : JsonInput) -> TokenTape raise ParseError {
  let tokens = TokenTape::new(input.len / 4 + 8)
  let bytes = input.bytes
  let base = input.base
  let len = input.len
  let mut index = 0
  while index < len {
    match scan_simd_token_block(input, tokens, index) {
      Some(next) => {
        index = next
        continue
      }
      None => ()
    }
    let ch = bytes[base + index]
    if is_ws(ch) {
      index += 1
    } else if ch == quote_byte() {
      let (end, escaped) = skip_string_literal(input, index)
      tokens.push(
        index,
        end,
        if escaped {
          token_string_escaped
        } else {
          token_string
        },
      )
      index = end
    } else {
      let code = token_code(ch)
      if code >= 0 {
        tokens.push(index, index + 1, code)
        index += 1
      } else if ch == b'-' || is_digit(ch) {
        let end = scan_number(input, index)
        tokens.push(index, end, token_number)
        index = end
      } else if starts_with(input, index, true_literal[:]) {
        tokens.push(index, index + 4, token_true)
        index += 4
      } else if starts_with(input, index, false_literal[:]) {
        tokens.push(index, index + 5, token_false)
        index += 5
      } else if starts_with(input, index, null_literal[:]) {
        tokens.push(index, index + 4, token_null)
        index += 4
      } else {
        raise UnexpectedChar(pos=index, expected="JSON token", found=ch)
      }
    }
  }
  tokens
}

///|
fn starts_with(input : JsonInput, index : Int, literal : BytesView) -> Bool {
  if index + literal.length() > input.len {
    false
  } else {
    let bytes = input.bytes
    let base = input.base
    for offset in 0..<literal.length() {
      if bytes[base + index + offset] != literal[offset] {
        return false
      }
    }
    true
  }
}

///|
fn scan_number(input : JsonInput, start : Int) -> Int raise ParseError {
  let bytes = input.bytes
  let base = input.base
  let len = input.len
  let mut index = start
  if index < len && bytes[base + index] == b'-' {
    index += 1
  }
  if index >= len {
    invalid_number(input, start, index)
  }
  if bytes[base + index] == b'0' {
    index += 1
    if index < len && is_digit(bytes[base + index]) {
      invalid_number(input, start, index + 1)
    }
  } else if is_one_to_nine(bytes[base + index]) {
    index += 1
    while index < len && is_digit(bytes[base + index]) {
      index += 1
    }
  } else {
    invalid_number(input, start, index + 1)
  }
  if index < len && bytes[base + index] == b'.' {
    index += 1
    let fraction_start = index
    while index < len && is_digit(bytes[base + index]) {
      index += 1
    }
    if index == fraction_start {
      invalid_number(input, start, index)
    }
  }
  if index < len && (bytes[base + index] == b'e' || bytes[base + index] == b'E') {
    index += 1
    if index < len &&
      (bytes[base + index] == b'+' || bytes[base + index] == b'-') {
      index += 1
    }
    let exponent_start = index
    while index < len && is_digit(bytes[base + index]) {
      index += 1
    }
    if index == exponent_start {
      invalid_number(input, start, index)
    }
  }
  index
}

///|
fn invalid_number(
  input : JsonInput,
  start : Int,
  end : Int,
) -> Unit raise ParseError {
  raise InvalidNumber(
    pos=start,
    lexeme=decode_utf8_segment(input, start, end, start),
  )
}

///|
fn skip_string_literal(
  input : JsonInput,
  start : Int,
) -> (Int, Bool) raise ParseError {
  let bytes = input.bytes
  let base = input.base
  let len = input.len
  let mut escaped = false
  let mut index = start + 1
  while index < len {
    if index + simd_lanes <= len {
      match first_string_simd_event(input, index) {
        None => {
          index += simd_lanes
          continue
        }
        Some(next) => index = next
      }
    }
    let ch = bytes[base + index]
    if ch == quote_byte() {
      return (index + 1, escaped)
    }
    if ch.to_int() < 32 {
      raise InvalidString(pos=index, message="unescaped control character")
    }
    if ch == backslash_byte() {
      escaped = true
      index = skip_escape(input, index)
    } else {
      index += 1
    }
  }
  raise UnexpectedEof(pos=start)
}

///|
fn is_ws(ch : Byte) -> Bool {
  ch == b' ' || ch == b'\n' || ch == b'\r' || ch == b'\t'
}

///|
fn is_digit(ch : Byte) -> Bool {
  b'0' <= ch && ch <= b'9'
}

///|
fn is_one_to_nine(ch : Byte) -> Bool {
  b'1' <= ch && ch <= b'9'
}

///|
fn skip_escape(input : JsonInput, slash : Int) -> Int raise ParseError {
  let pos = slash + 1
  if pos >= input.len {
    raise UnexpectedEof(pos=slash)
  }
  let ch = input.at(pos)
  if is_simple_escape(ch) {
    pos + 1
  } else if ch == b'u' {
    let code = parse_hex4(input, pos + 1)
    if code.is_leading_surrogate() {
      let next_slash = pos + 5
      if next_slash + 6 > input.len ||
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
      next_slash + 6
    } else if code.is_trailing_surrogate() {
      raise InvalidString(
        pos~,
        message="trailing surrogate without leading surrogate",
      )
    } else {
      pos + 5
    }
  } else {
    raise InvalidString(pos~, message="invalid escape")
  }
}

///|
fn is_simple_escape(ch : Byte) -> Bool {
  ch == quote_byte() ||
  ch == backslash_byte() ||
  ch == b'/' ||
  ch == b'b' ||
  ch == b'f' ||
  ch == b'n' ||
  ch == b'r' ||
  ch == b't'
}

///|
fn parse_hex4(input : JsonInput, start : Int) -> UInt16 raise ParseError {
  if start + 4 > input.len {
    raise UnexpectedEof(pos=start)
  }
  let mut value = 0
  for offset in 0..<4 {
    match hex_value(input.at(start + offset)) {
      Some(digit) => value = value * 16 + digit
      None =>
        raise InvalidString(
          pos=start + offset,
          message="invalid unicode escape",
        )
    }
  }
  value.reinterpret_as_uint().to_uint16()
}

///|
fn hex_value(ch : Byte) -> Int? {
  let value = ch.to_int()
  if 48 <= value && value <= 57 {
    Some(value - 48)
  } else if 65 <= value && value <= 70 {
    Some(value - 55)
  } else if 97 <= value && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn decode_utf8_segment(
  input : JsonInput,
  start : Int,
  end : Int,
  pos : Int,
) -> String raise ParseError {
  decode_utf8_view(input.view(start, end), pos)
}

///|
fn decode_utf8_view(input : BytesView, pos : Int) -> String raise ParseError {
  @utf8.decode(input) catch {
    _ => raise InvalidString(pos~, message="invalid UTF-8")
  }
}

///|
fn decode_surrogate_pair(high : UInt16, low : UInt16) -> Char? {
  let high_bits = high.to_int() - 0xd800
  let low_bits = low.to_int() - 0xdc00
  (0x10000 + high_bits * 0x400 + low_bits).to_char()
}

///|
fn code_unit(value : Int) -> UInt16 {
  value.reinterpret_as_uint().to_uint16()
}

///|
fn ascii_char(value : Int) -> Char {
  code_unit(value).to_char().unwrap()
}
