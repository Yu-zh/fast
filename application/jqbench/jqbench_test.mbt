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

// Head-to-head: extracting a top-level field (`.score`) from a JSON object,
// comparing Yu-zh/jq against shina1024/jqx and mizchi/jq.

///|
fn bytes(s : String) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(s.length(), 0)
  let mut i = 0
  for c in s {
    out[i] = c.to_int().to_byte()
    i = i + 1
  }
  out
}

///|
fn jqx_first(filter : String, json : String) -> String {
  let r = @jqx.run_json_text(filter, json) catch { _ => [] }
  if r.length() > 0 {
    r[0]
  } else {
    ""
  }
}

///|
fn mizchi_first(filter : String, json : String) -> String {
  let r = @mjq.run_string(filter, json) catch { _ => [] }
  if r.length() > 0 {
    r[0]
  } else {
    ""
  }
}

///|
test "all three extract the same field value" {
  let json = sample_json()
  @test.assert_eq(@ourjq.field(bytes(json), bytes("score")), Some(bytes("98")))
  @test.assert_eq(jqx_first(".score", json), "98")
  @test.assert_eq(mizchi_first(".score", json), "98")
}

///|
test "bench ours field .score" (it : @bench.T) {
  let jb = bytes(sample_json())
  let kb = bytes("score")
  it.bench(fn() { it.keep(@ourjq.field(jb, kb)) })
}

///|
test "bench jqx .score" (it : @bench.T) {
  let js = sample_json()
  it.bench(fn() { it.keep(jqx_first(".score", js)) })
}

///|
test "bench mizchi .score" (it : @bench.T) {
  let js = sample_json()
  it.bench(fn() { it.keep(mizchi_first(".score", js)) })
}

///|
test "bench ours field .score (big)" (it : @bench.T) {
  let jb = bytes(sample_json_big())
  let kb = bytes("score")
  it.bench(fn() { it.keep(@ourjq.field(jb, kb)) })
}

///|
test "bench jqx .score (big)" (it : @bench.T) {
  let js = sample_json_big()
  it.bench(fn() { it.keep(jqx_first(".score", js)) })
}

///|
test "bench mizchi .score (big)" (it : @bench.T) {
  let js = sample_json_big()
  it.bench(fn() { it.keep(mizchi_first(".score", js)) })
}
