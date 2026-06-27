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
fn positions_ref(bytes : FixedArray[Byte], delim : Byte) -> Array[Int]? {
  let out = []
  let mut in_quote = false
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b == b'"' {
      in_quote = !in_quote
    } else if !in_quote && (b == delim || b == b'\n') {
      out.push(i)
    }
  }
  if in_quote {
    return None
  }
  Some(out)
}

///|
/// Render split_records output as concrete byte slices for readable asserts.
fn fields(bytes : FixedArray[Byte], delim : Byte) -> Array[Array[Bytes]]? {
  guard @csv.split_records(bytes, delimiter=delim) is Some(rows) else {
    return None
  }
  let out = []
  for row in rows {
    let r = []
    for field in row {
      let (s, e) = field
      let fa : Array[Byte] = []
      for k in s..<e {
        fa.push(bytes[k])
      }
      r.push(Bytes::from_array(fa))
    }
    out.push(r)
  }
  Some(out)
}

///|
test "unquoted_positions handles quotes, doubled quotes, newlines" {
  let doc = of(b"a,b,c\n\"x,y\",\"he said \"\"hi\"\"\",z\nlast\n")
  @test.assert_eq(@csv.unquoted_positions(doc), positions_ref(doc, b','))
  // a quoted field containing a newline must not split the record
  let multiline = of(b"\"line1\nline2\",b\nc,d")
  @test.assert_eq(
    @csv.unquoted_positions(multiline),
    positions_ref(multiline, b','),
  )
  // unterminated quote
  @test.assert_eq(@csv.unquoted_positions(of(b"a,\"bcd")), None)
}

///|
test "split_records basic rows and fields" {
  @test.assert_eq(
    fields(of(b"a,b,c\nd,e,f"), b','),
    Some([[b"a", b"b", b"c"], [b"d", b"e", b"f"]]),
  )
  // trailing newline does not add an empty record; \r\n is trimmed
  @test.assert_eq(
    fields(of(b"a,b\r\nc,d\r\n"), b','),
    Some([[b"a", b"b"], [b"c", b"d"]]),
  )
  // trailing delimiter yields an empty final field
  @test.assert_eq(fields(of(b"a,b,"), b','), Some([[b"a", b"b", b""]]))
  // quoted fields keep their quotes; embedded delimiters/newlines are intact
  @test.assert_eq(
    fields(of(b"\"a,b\",c\n\"x\ny\",z"), b','),
    Some([[b"\"a,b\"", b"c"], [b"\"x\ny\"", b"z"]]),
  )
  // empty input has no records
  @test.assert_eq(fields(of(b""), b','), Some([]))
}

///|
test "alternate delimiter" {
  @test.assert_eq(
    fields(of(b"a\tb\tc\nd\te\tf"), b'\t'),
    Some([[b"a", b"b", b"c"], [b"d", b"e", b"f"]]),
  )
}

///|
/// Cross-check the SIMD scan against the scalar reference over a long,
/// realistic document that spans many 64-byte strides.
test "unquoted_positions matches reference on a long document" {
  let row = b"12345,\"a quoted, value\",hello world,\"x\"\"y\",678\n"
  let reps = 40
  let total = row.length() * reps
  let doc : FixedArray[Byte] = FixedArray::make(total, 0)
  let mut pos = 0
  for _ in 0..<reps {
    for j in 0..<row.length() {
      doc[pos + j] = row[j]
    }
    pos = pos + row.length()
  }
  @test.assert_eq(@csv.unquoted_positions(doc), positions_ref(doc, b','))
}
