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
fn json_bench_payload(n : Int) -> String {
  let out = StringBuilder(size_hint=n * 72)
  out.write_string("[")
  for index in 0..<n {
    if index > 0 {
      out.write_string(",")
    }
    out.write_string("{\"id\":")
    out.write_object(index)
    out.write_string(",\"active\":")
    out.write_string(if index % 3 == 0 { "true" } else { "false" })
    out.write_string(",\"name\":\"item-")
    out.write_object(index)
    out.write_string("\",\"values\":[")
    out.write_object(index)
    out.write_string(",")
    out.write_object(index + 1)
    out.write_string(",")
    out.write_object(index + 2)
    out.write_string("]}")
  }
  out.write_string("]")
  out.to_string()
}

///|
fn json_bench_payload_bytes(n : Int) -> Bytes {
  @utf8.encode(json_bench_payload(n)[:])
}

///|
test "bench fast.json parse_bytes records=128" (it : @bench.T) {
  let input = json_bench_payload_bytes(128)
  it.bench(fn() {
    let value = try! @json.parse_bytes(input[:])
    it.keep(value)
  })
}

///|
test "bench core.json parse records=128" (it : @bench.T) {
  let input = json_bench_payload(128)
  it.bench(fn() {
    let value = try! @core_json.parse(input[:])
    it.keep(value)
  })
}

///|
test "bench fast.json parse_bytes records=1024" (it : @bench.T) {
  let input = json_bench_payload_bytes(1024)
  it.bench(fn() {
    let value = try! @json.parse_bytes(input[:])
    it.keep(value)
  })
}

///|
test "bench core.json parse records=1024" (it : @bench.T) {
  let input = json_bench_payload(1024)
  it.bench(fn() {
    let value = try! @core_json.parse(input[:])
    it.keep(value)
  })
}
