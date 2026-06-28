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
test "generate yields in-range tokens, is deterministic, and is greedy" {
  let c = @infer.Config::{
    dim: 8,
    hidden_dim: 16,
    n_layers: 2,
    n_heads: 2,
    n_kv_heads: 2,
    vocab_size: 16,
    seq_len: 8,
  }
  let w = build(c, 0xfeed1234) // build/Rng come from model_test.mbt
  let model = @infer.Transformer::new(c, w)
  let prompt = [1, 5]
  let out = @infer.generate(model, prompt, 6)
  // min(steps, seq_len) tokens, all valid ids
  @test.assert_eq(out.length(), 6)
  for t in out {
    @test.assert_eq(t >= 0 && t < c.vocab_size, true)
  }
  // the forced-prompt token appears first
  @test.assert_eq(out[0], 5)
  // deterministic across fresh models
  let model2 = @infer.Transformer::new(c, w)
  let out2 = @infer.generate(model2, prompt, 6)
  @test.assert_eq(out, out2)
  // the first generated token (after the prompt) is the greedy argmax at pos 1
  let model3 = @infer.Transformer::new(c, w)
  let _ = model3.forward(1, 0)
  let logits = copy_f(model3.forward(5, 1))
  @test.assert_eq(out[1], argmax_f(logits))
}

///|
test "generate clamps steps to seq_len and handles empty prompt" {
  let c = @infer.Config::{
    dim: 8,
    hidden_dim: 16,
    n_layers: 1,
    n_heads: 2,
    n_kv_heads: 2,
    vocab_size: 16,
    seq_len: 4,
  }
  let w = build(c, 0xabcd)
  let model = @infer.Transformer::new(c, w)
  // steps beyond seq_len are clamped
  @test.assert_eq(@infer.generate(model, [2], 100).length(), 4)
  // empty prompt -> empty output
  @test.assert_eq(@infer.generate(model, [], 5).length(), 0)
}
