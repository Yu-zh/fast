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
fn put_i32(buf : Array[Byte], v : Int) -> Unit {
  let u = v.reinterpret_as_uint()
  buf.push((u & 0xff).to_byte())
  buf.push(((u >> 8) & 0xff).to_byte())
  buf.push(((u >> 16) & 0xff).to_byte())
  buf.push(((u >> 24) & 0xff).to_byte())
}

///|
fn put_f32(buf : Array[Byte], f : Float) -> Unit {
  let u = f.reinterpret_as_uint()
  buf.push((u & 0xff).to_byte())
  buf.push(((u >> 8) & 0xff).to_byte())
  buf.push(((u >> 16) & 0xff).to_byte())
  buf.push(((u >> 24) & 0xff).to_byte())
}

///|
test "load_checkpoint round-trips a self-serialized model (shared weights)" {
  // a tiny shared-weights config
  let dim = 4
  let hidden_dim = 8
  let n_layers = 2
  let n_heads = 2
  let n_kv_heads = 1
  let vocab = 6
  let seq_len = 5
  let head_size = dim / n_heads
  let kv_dim = n_kv_heads * head_size
  let buf : Array[Byte] = []
  // header (positive vocab => shared classifier)
  put_i32(buf, dim)
  put_i32(buf, hidden_dim)
  put_i32(buf, n_layers)
  put_i32(buf, n_heads)
  put_i32(buf, n_kv_heads)
  put_i32(buf, vocab)
  put_i32(buf, seq_len)
  // a deterministic stream of float values for every weight, in order
  let mut counter = 0
  let next = fn() {
    let v = Float::from_int(counter)
    counter = counter + 1
    v
  }
  let sizes = [
    vocab * dim, // token_embedding
    n_layers * dim, // rms_att
    n_layers * dim * dim, // wq
    n_layers * kv_dim * dim, // wk
    n_layers * kv_dim * dim, // wv
    n_layers * dim * dim, // wo
    n_layers * dim, // rms_ffn
    n_layers * hidden_dim * dim, // w1
    n_layers * dim * hidden_dim, // w2
    n_layers * hidden_dim * dim, // w3
    dim, // rms_final
    seq_len * head_size / 2 * 2, // skipped RoPE tables
  ]
  for sz in sizes {
    for _ in 0..<sz {
      put_f32(buf, next())
    }
  }
  let (config, weights) = @infer.load_checkpoint(Bytes::from_array(buf))
  // config matches
  @test.assert_eq(config.dim, dim)
  @test.assert_eq(config.hidden_dim, hidden_dim)
  @test.assert_eq(config.n_layers, n_layers)
  @test.assert_eq(config.n_heads, n_heads)
  @test.assert_eq(config.n_kv_heads, n_kv_heads)
  @test.assert_eq(config.vocab_size, vocab)
  @test.assert_eq(config.seq_len, seq_len)
  // first weights stream is the embedding: values 0,1,2,...
  @test.assert_eq(weights.token_embedding[0], 0.0)
  @test.assert_eq(weights.token_embedding[5], 5.0)
  // rms_att starts right after the embedding (vocab*dim values)
  @test.assert_eq(weights.rms_att[0][0], Float::from_int(vocab * dim))
  // shared weights: classifier is the embedding
  @test.assert_eq(weights.wcls[7], weights.token_embedding[7])
  // a forward pass runs on the loaded weights without error
  let model = @infer.Transformer::new(config, weights)
  let logits = model.forward(0, 0)
  @test.assert_eq(logits.length(), vocab)
}
