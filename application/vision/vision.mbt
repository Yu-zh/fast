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

// An INT8 quantized two-layer MLP image classifier (e.g. for MNIST-shaped
// inputs), built on `Yu-zh/fast`. Each layer is `gemm.gemm_i8` — the SIMD int8
// matrix multiply (`i32x4_dot_i16x8_s`, ~4x) — followed by `relu_i32`; between
// layers the int32 activations are requantized back to int8 by an arithmetic
// shift. The final layer's logits are reduced with `argmax_i32`. This is the
// same int8 idea as the `Yu-zh/infer` transformer, scaled down to a classifier.

///|
/// A two-layer int8 MLP: `in_dim -> hidden -> out_dim`.
pub struct MLP {
  w1 : FixedArray[Byte] // [hidden x in_dim] int8, row-major
  w2 : FixedArray[Byte] // [out_dim x hidden] int8, row-major
  in_dim : Int
  hidden : Int
  out_dim : Int
  shift : Int // requantization shift applied to layer-1 activations
}

///|
/// Builds a classifier from int8 weight matrices. `w1` is `[hidden x in_dim]`
/// and `w2` is `[out_dim x hidden]`, each row-major (one output neuron's
/// weights contiguous). `shift` scales the int32 hidden activations back into
/// int8 range.
pub fn MLP::new(
  w1 : FixedArray[Byte],
  w2 : FixedArray[Byte],
  in_dim : Int,
  hidden : Int,
  out_dim : Int,
  shift : Int,
) -> MLP {
  MLP::{ w1, w2, in_dim, hidden, out_dim, shift }
}

///|
/// Requantizes int32 activations to int8 by an arithmetic right shift, clamped
/// to [-127, 127].
fn requantize(x : FixedArray[Int], shift : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(x.length(), 0)
  for i in 0..<x.length() {
    let v = x[i] >> shift
    let c = if v > 127 { 127 } else if v < -127 { -127 } else { v }
    out[i] = (c & 0xFF).to_byte()
  }
  out
}

///|
/// Runs the forward pass and returns the raw int32 output logits.
pub fn MLP::logits(self : MLP, input : FixedArray[Byte]) -> FixedArray[Int] {
  let h = @gemm.gemm_i8(input, self.w1, 1, self.in_dim, self.hidden)
  @gemm.relu_i32(h)
  let h8 = requantize(h, self.shift)
  @gemm.gemm_i8(h8, self.w2, 1, self.hidden, self.out_dim)
}

///|
/// Classifies `input` (length `in_dim`, signed int8) and returns the predicted
/// class index, or `-1` if the model has no outputs.
pub fn MLP::classify(self : MLP, input : FixedArray[Byte]) -> Int {
  match @gemm.argmax_i32(self.logits(input)) {
    Some(c) => c
    None => -1
  }
}

///|
/// Maps unsigned 0-255 grayscale pixels to signed int8 (subtracting 128), the
/// representation `gemm_i8` expects for image input.
pub fn center(pixels : FixedArray[Byte]) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(pixels.length(), 0)
  for i in 0..<pixels.length() {
    out[i] = (pixels[i].to_int() - 128).to_byte()
  }
  out
}
