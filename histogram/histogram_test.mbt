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
test "counts" {
  let c = @histogram.counts(of(b"banana"))
  @test.assert_eq(c[b'a'.to_int()], 3)
  @test.assert_eq(c[b'n'.to_int()], 2)
  @test.assert_eq(c[b'b'.to_int()], 1)
  @test.assert_eq(c[b'z'.to_int()], 0)
  @test.assert_eq(@histogram.counts(of(b"")).length(), 256)
}

///|
test "count_of matches counts and a scalar scan" {
  let n = 500
  let data : FixedArray[Byte] = FixedArray::make(n, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<n {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    data[i] = (state & 0x0f).to_byte() // small alphabet so counts are large
  }
  let c = @histogram.counts(data)
  // the full histogram sums to the input length
  let mut total = 0
  for v in 0..<256 {
    total = total + c[v]
    @test.assert_eq(@histogram.count_of(data, v.to_byte()), c[v])
  }
  @test.assert_eq(total, n)
}
