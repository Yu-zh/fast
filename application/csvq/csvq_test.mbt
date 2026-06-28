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
test "parses cells and aggregates a numeric column" {
  let table = @csvq.parse(of(b"name,score\nalice,10\nbob,25\ncarol,5\n")).unwrap()
  @test.assert_eq(table.cell(1, 0), of(b"alice"))
  @test.assert_eq(table.cell(2, 1), of(b"25"))
  // header cell "score" is non-numeric and skipped by the aggregates
  @test.assert_eq(table.sum_int(1), 40)
  @test.assert_eq(table.count_int(1), 3)
  @test.assert_eq(table.max_int(1), Some(25))
  @test.assert_eq(table.min_int(1), Some(5))
}

///|
test "mean over the numeric cells" {
  let table = @csvq.parse(of(b"v\n2\n4\n6\n")).unwrap()
  @test.assert_eq(table.sum_int(0), 12)
  @test.assert_eq(table.mean_int(0), Some(4.0))
}

///|
test "a column with no integers has no min/max/mean" {
  let table = @csvq.parse(of(b"a,b\nx,y\n")).unwrap()
  @test.assert_eq(table.max_int(0), None)
  @test.assert_eq(table.mean_int(0), None)
}
