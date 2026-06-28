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

// The autoregressive decoding loop. It feeds the prompt tokens through the
// transformer (filling the KV cache), then greedily extends the sequence by
// taking the argmax logit at each step. Sampling strategies (temperature,
// top-k/top-p) and a tokenizer are the natural follow-ons.

///|
fn argmax_logits(a : FixedArray[Float]) -> Int {
  let mut best = 0
  for i in 1..<a.length() {
    if a[i] > a[best] {
      best = i
    }
  }
  best
}

///|
/// Greedily decodes from `model`. The `prompt` token ids prime the model; once
/// they are consumed each subsequent token is the argmax of the logits. Returns
/// the token emitted at every step (the prompt continuation followed by the
/// generated tokens); its length is `min(steps, seq_len)`. The prompt must be
/// non-empty.
pub fn generate(
  model : Transformer,
  prompt : Array[Int],
  steps : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  let cap = model.config.seq_len
  let limit = if steps < cap { steps } else { cap }
  let prompt_len = prompt.length()
  if prompt_len == 0 || limit <= 0 {
    return out
  }
  let mut token = prompt[0]
  let mut pos = 0
  while pos < limit {
    let logits = model.forward(token, pos)
    let next = if pos + 1 < prompt_len {
      prompt[pos + 1]
    } else {
      argmax_logits(logits)
    }
    out.push(next)
    token = next
    pos = pos + 1
  }
  out
}
