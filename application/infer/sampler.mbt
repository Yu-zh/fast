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

// Token sampling from logits (after llama2.c). `temperature == 0` is greedy
// argmax; otherwise logits are temperature-scaled, softmaxed, and sampled
// either multinomially or with nucleus (top-p) truncation. A small seeded
// xorshift RNG keeps runs reproducible.

///|
/// A seeded pseudo-random generator for reproducible sampling.
pub(all) struct Rng {
  mut state : UInt
}

///|
/// Creates an RNG from `seed` (0 is remapped to a nonzero state).
pub fn Rng::new(seed : UInt) -> Rng {
  Rng::{ state: if seed == 0U { 0x9e3779b9 } else { seed } }
}

///|
fn Rng::next_u32(self : Rng) -> UInt {
  self.state = self.state ^ (self.state << 13)
  self.state = self.state ^ (self.state >> 17)
  self.state = self.state ^ (self.state << 5)
  self.state
}

///|
/// Returns a float in [0, 1).
pub fn Rng::next_float(self : Rng) -> Float {
  Float::from_int((self.next_u32() >> 8).reinterpret_as_int()) /
  (16777216.0 : Float)
}

///|
fn sample_mult(probs : FixedArray[Float], coin : Float) -> Int {
  let n = probs.length()
  let mut cdf = (0.0 : Float)
  for i in 0..<n {
    cdf = cdf + probs[i]
    if coin < cdf {
      return i
    }
  }
  n - 1
}

///|
fn sample_topp(probs : FixedArray[Float], topp : Float, coin : Float) -> Int {
  let n = probs.length()
  let idx : Array[Int] = []
  for i in 0..<n {
    idx.push(i)
  }
  // sort indices by descending probability
  idx.sort_by(fn(a, b) {
    if probs[a] > probs[b] {
      -1
    } else if probs[a] < probs[b] {
      1
    } else {
      0
    }
  })
  // smallest prefix whose cumulative probability reaches topp
  let mut cum = (0.0 : Float)
  let mut last = n - 1
  for k in 0..<n {
    cum = cum + probs[idx[k]]
    if cum >= topp {
      last = k
      break
    }
  }
  // sample within the nucleus, renormalized to its mass
  let target = coin * cum
  let mut cdf = (0.0 : Float)
  for k in 0..<(last + 1) {
    cdf = cdf + probs[idx[k]]
    if target < cdf {
      return idx[k]
    }
  }
  idx[last]
}

///|
/// Picks the next token from `logits`. With `temperature == 0` this is greedy
/// argmax. Otherwise logits are scaled by `1/temperature` and softmaxed, then
/// sampled multinomially, or with nucleus (top-p) truncation when
/// `0 < topp < 1`.
pub fn sample(
  logits : FixedArray[Float],
  temperature : Float,
  topp : Float,
  rng : Rng,
) -> Int {
  if temperature <= (0.0 : Float) {
    return argmax_logits(logits)
  }
  let n = logits.length()
  let probs : FixedArray[Float] = FixedArray::make(n, 0.0)
  for i in 0..<n {
    probs[i] = logits[i] / temperature
  }
  softmax(probs, 0, n)
  let coin = rng.next_float()
  if topp <= (0.0 : Float) || topp >= (1.0 : Float) {
    sample_mult(probs, coin)
  } else {
    sample_topp(probs, topp, coin)
  }
}
