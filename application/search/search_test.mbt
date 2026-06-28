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
test "find_all and count locate every occurrence" {
  let h = of(b"abcabcabc")
  @test.assert_eq(@search.find_all(h, of(b"abc")), [0, 3, 6])
  @test.assert_eq(@search.count(h, of(b"abc")), 3)
  @test.assert_eq(@search.find_all(h, of(b"zzz")), [])
}

///|
test "search_lines reports matching lines with 1-based numbers" {
  let text = of(b"first line\nsecond has foo\nthird\nfoo again here\n")
  let m = @search.search_lines(text, of(b"foo"))
  @test.assert_eq(m.length(), 2)
  @test.assert_eq(m[0].line, 2)
  @test.assert_eq(m[0].text(text), of(b"second has foo"))
  @test.assert_eq(m[1].line, 4)
  @test.assert_eq(m[1].text(text), of(b"foo again here"))
}

///|
test "no matches yields no lines" {
  @test.assert_eq(
    @search.search_lines(of(b"hello\nworld"), of(b"xyz")).length(),
    0,
  )
}
