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
fn put_token(buf : Array[Byte], text : String, score : Float) -> Unit {
  put_f32(buf, score) // put_f32 / put_i32 come from loader_test.mbt
  let bs : Array[Byte] = []
  for c in text.iter() {
    bs.push(c.to_int().to_byte())
  }
  put_i32(buf, bs.length())
  for b in bs {
    buf.push(b)
  }
}

///|
fn tiny_tokenizer() -> @infer.Tokenizer {
  let buf : Array[Byte] = []
  put_i32(buf, 8) // max_token_length (unused by the parser)
  put_token(buf, "<unk>", 0.0) // 0
  put_token(buf, "<s>", 0.0) // 1
  put_token(buf, "</s>", 0.0) // 2
  put_token(buf, " ", 0.0) // 3 (dummy prefix)
  put_token(buf, "a", 0.0) // 4
  put_token(buf, "b", 0.0) // 5
  put_token(buf, "ab", 1.0) // 6  (merge of a + b)
  put_token(buf, "c", 0.0) // 7
  put_token(buf, "abc", 2.0) // 8  (merge of ab + c)
  put_token(buf, "<0x0A>", 0.0) // 9 (a byte token)
  @infer.Tokenizer::from_bytes(Bytes::from_array(buf), 10)
}

///|
test "encode applies dummy prefix and greedy merges" {
  let tok = tiny_tokenizer()
  // "abc": prefix space (3), then a+b -> ab (6), ab+c -> abc (8)
  @test.assert_eq(tok.encode("abc", false, false), [3, 8])
  // BOS (1) and EOS (2) bracket the sequence
  @test.assert_eq(tok.encode("abc", true, true), [1, 3, 8, 2])
  // partial: "ab" merges once
  @test.assert_eq(tok.encode("ab", false, false), [3, 6])
}

///|
test "decode reverses tokens, byte tokens, and the dummy prefix" {
  let tok = tiny_tokenizer()
  @test.assert_eq(tok.decode(0, 8), Bytes::from_array([b'a', b'b', b'c']))
  // "<0x0A>" decodes to the raw newline byte
  @test.assert_eq(tok.decode(0, 9), Bytes::from_array([b'\n']))
  // a leading dummy-prefix space is dropped right after BOS
  @test.assert_eq(tok.decode(1, 3), Bytes::from_array([]))
  // but kept otherwise
  @test.assert_eq(tok.decode(0, 3), Bytes::from_array([b' ']))
}
