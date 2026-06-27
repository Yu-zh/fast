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
test "stage1 emits structural and pseudo-structural tokens" {
  let input : Bytes = b"{\"a\":[1,2],\"b\":\"{,}\"}"
  let tokens = token_indexes(input[:])
  @test.assert_eq(tokens.map(item => item.pos), [
    0, 1, 4, 5, 6, 7, 8, 9, 10, 11, 14, 15, 20,
  ])
  @test.assert_eq(tokens.map(item => item.end), [
    1, 4, 5, 6, 7, 8, 9, 10, 11, 14, 15, 20, 21,
  ])
  assert_true(tokens[0].kind is ObjectStart)
  assert_true(tokens[1].kind is StringToken)
  assert_true(tokens[4].kind is NumberToken)
  assert_true(tokens[11].kind is StringToken)
}
