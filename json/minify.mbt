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
pub fn minify(input : String) -> String raise ParseError {
  let bytes = @utf8.encode(input[:])
  minify_bytes(bytes[:])
}

///|
pub fn minify_bytes(input : BytesView) -> String raise ParseError {
  let source = JsonInput::from_view(input)
  let _ = parse_input(source, max_nesting_depth=default_max_nesting_depth)
  let out : Array[Byte] = []
  let bytes = source.bytes
  let base = source.base
  let len = source.len
  let mut index = 0
  while index < len {
    let ch = bytes[base + index]
    if ch == quote_byte() {
      let (end, _) = skip_string_literal(source, index)
      copy_bytes(out, source, index, end)
      index = end
    } else if is_ws(ch) {
      index += 1
    } else {
      out.push(ch)
      index += 1
    }
  }
  let bytes = Bytes::from_array(out)
  decode_utf8_view(bytes[:], 0)
}

///|
fn copy_bytes(
  out : Array[Byte],
  input : JsonInput,
  start : Int,
  end : Int,
) -> Unit {
  let bytes = input.bytes
  let base = input.base
  for index in start..<end {
    out.push(bytes[base + index])
  }
}
