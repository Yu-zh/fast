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
fn is_ws(b : Byte) -> Bool {
  b == b' ' || b == b'\t' || b == b'\n' || b == b'\r'
}

///|
fn is_op(b : Byte) -> Bool {
  b == b'{' || b == b'}' || b == b'[' || b == b']' || b == b':' || b == b','
}

///|
/// Byte-at-a-time reference implementing the same marking rules as the
/// SIMD scanner.
fn reference(bytes : FixedArray[Byte]) -> Array[Int]? {
  let out : Array[Int] = []
  let mut parity = false // inside string, opening quote inclusive
  let mut escape_pending = false
  let mut prev_nonquote_scalar = false
  for i in 0..<bytes.length() {
    let b = bytes[i]
    let escaped = escape_pending
    escape_pending = b == b'\\' && !escaped
    let is_quote = b == b'"' && !escaped
    if is_quote {
      parity = !parity
    }
    let in_string = parity
    let string_tail = in_string != is_quote
    let scalar = !is_op(b) && !is_ws(b)
    let structural = (is_op(b) || (scalar && !prev_nonquote_scalar)) &&
      !string_tail
    prev_nonquote_scalar = scalar && !is_quote
    if structural {
      out.push(i)
    }
  }
  if parity {
    return None
  }
  Some(out)
}

///|
fn of_str(s : Bytes) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  for i in 0..<s.length() {
    out[i] = s[i]
  }
  out
}

///|
test "hand-checked documents" {
  @test.assert_eq(
    @json.structural_indices(FixedArray::make(0, b'\x00')),
    Some([]),
  )
  @test.assert_eq(@json.structural_indices(of_str(b"[]")), Some([0, 1]))
  // {"a":1}  ->  '{' '"a"' ':' '1' '}'
  @test.assert_eq(
    @json.structural_indices(of_str(b"{\"a\":1}")),
    Some([0, 1, 4, 5, 6]),
  )
  // whitespace separated atoms
  @test.assert_eq(
    @json.structural_indices(of_str(b" [ 1 , true ] ")),
    Some([1, 3, 5, 7, 12]),
  )
  // escaped quote inside a string: only the opening quote is marked
  @test.assert_eq(@json.structural_indices(of_str(b"\"a\\\"b\"")), Some([0]))
  // structural characters inside strings are content, not structure
  @test.assert_eq(@json.structural_indices(of_str(b"\"{[:,]}\"")), Some([0]))
  // even backslash run before quote: the quote closes the string
  @test.assert_eq(@json.structural_indices(of_str(b"\"a\\\\\"")), Some([0]))
  // unclosed strings
  @test.assert_eq(@json.structural_indices(of_str(b"\"abc")), None)
  @test.assert_eq(@json.structural_indices(of_str(b"\"abc\\\"")), None)
}

///|
test "multi-number and atom starts" {
  // numbers and atoms get exactly one mark at their first byte
  @test.assert_eq(
    @json.structural_indices(of_str(b"[123, -4.5e6, null]")),
    Some([0, 1, 4, 6, 12, 14, 18]),
  )
}

///|
test "strings spanning stride boundaries" {
  // a string opening before and closing after the 64-byte boundary, with
  // structural characters inside that must be ignored
  for open_pos in [50, 55, 60, 62, 63] {
    let bytes : FixedArray[Byte] = FixedArray::make(130, b' ')
    bytes[open_pos] = b'"'
    for j in (open_pos + 1)..<80 {
      bytes[j] = if j % 3 == 0 { b'{' } else { b'x' }
    }
    bytes[80] = b'"'
    @test.assert_eq(@json.structural_indices(bytes), Some([open_pos]))
  }
  // a backslash immediately before the boundary escaping a quote after it
  let bytes : FixedArray[Byte] = FixedArray::make(130, b' ')
  bytes[10] = b'"'
  bytes[63] = b'\\'
  bytes[64] = b'"'
  bytes[70] = b'"'
  @test.assert_eq(@json.structural_indices(bytes), Some([10]))
}

///|
test "long backslash runs across boundaries" {
  // runs of every length ending at the stride boundary, followed by a
  // quote: run parity decides whether the string closes
  for run in 1..<10 {
    let bytes : FixedArray[Byte] = FixedArray::make(96, b'x')
    bytes[0] = b'"'
    for j in 0..<run {
      bytes[64 - run + j] = b'\\'
    }
    bytes[64] = b'"'
    @test.assert_eq(@json.structural_indices(bytes), reference(bytes))
  }
}

///|
test "randomized cross-check" {
  let mut state = 0xdeadbeefU
  fn next() -> UInt {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state
  }

  // byte soup biased towards JSON syntax characters
  let alphabet : FixedArray[Byte] = [
    b'"', b'\\', b'{', b'}', b'[', b']', b':', b',', b' ', b'\n', b'a', b'1', b'-',
    b'.', b't', b'x',
  ]
  for _ in 0..<400 {
    let len = (next() % 200).reinterpret_as_int()
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      bytes[i] = alphabet[(next() % 16).reinterpret_as_int()]
    }
    @test.assert_eq(@json.structural_indices(bytes), reference(bytes))
  }
}

///|
test "realistic document cross-check" {
  let doc = of_str(
    b"{\"id\": 123456, \"name\": \"item \\\"123\\\"\", \"price\": -1.25e3, \"tags\": [\"a\", \"b\\\\\", \"c\"], \"meta\": {\"ok\": true, \"note\": null}}",
  )
  let got = @json.structural_indices(doc)
  @test.assert_eq(got, reference(doc))
  // the first few marks are easy to verify by eye:
  // '{' at 0, key quote at 1, ':' at 5, the number's first digit at 7
  match got {
    Some(indices) => @test.assert_eq(indices[0:4].to_owned(), [0, 1, 5, 7])
    None => @test.fail("expected marks")
  }
}
