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
test "splits NDJSON into lines and filters by substring" {
  let nd = of(b"{\"a\":1}\n{\"a\":2,\"name\":\"bob\"}\n{\"a\":3}")
  @test.assert_eq(@jq.lines(nd).length(), 3)
  let sel = @jq.select_contains(nd, of(b"bob"))
  @test.assert_eq(sel.length(), 1)
  @test.assert_eq(sel[0], of(b"{\"a\":2,\"name\":\"bob\"}"))
}

///|
test "extracts top-level fields of a flat object" {
  let obj = of(b"{\"name\": \"alice\", \"age\": 30, \"active\": true}")
  @test.assert_eq(@jq.field(obj, of(b"name")), Some(of(b"alice")))
  @test.assert_eq(@jq.field(obj, of(b"age")), Some(of(b"30")))
  @test.assert_eq(@jq.field(obj, of(b"active")), Some(of(b"true")))
  @test.assert_eq(@jq.field(obj, of(b"missing")), None)
}

///|
test "minify strips insignificant whitespace" {
  @test.assert_eq(@jq.minify(of(b"{ \"a\" : 1 }")), Some(of(b"{\"a\":1}")))
}
