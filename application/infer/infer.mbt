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

// Yu-zh/infer — a SIMD-accelerated inference runtime built on the Yu-zh/fast
// kernels. This is the seed: a single quantized dense layer + argmax, enough
// to prove the cross-module wiring. Transformer building blocks (RMSNorm,
// softmax, SwiGLU, RoPE, attention + KV cache, a tokenizer, and a checkpoint
// loader) will land here as their own packages, composing the kernels in
// `Yu-zh/fast` (gemm, vecmath, reduce, ...).

///|
/// Runs a single int8 dense layer over `input` (length `features`) against
/// `weights` (`classes x features`, row-major = each class's weight row), then
/// returns the predicted class via argmax of the logits.
pub fn classify(
  input : FixedArray[Byte],
  weights : FixedArray[Byte],
  classes : Int,
  features : Int,
) -> Int {
  let logits = @gemm.gemm_i8(input, weights, 1, features, classes)
  match @gemm.argmax_i32(logits) {
    Some(c) => c
    None => -1
  }
}
