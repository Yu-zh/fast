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
test "greedy sampling picks the argmax" {
  let logits : FixedArray[Float] = [1.0, 3.0, 2.0, 0.5]
  let rng = @infer.Rng::new(1)
  @test.assert_eq(@infer.sample(logits, 0.0, 0.0, rng), 1)
}

///|
test "a one-hot distribution always samples its peak" {
  // a dominant logit -> softmax ~ one-hot, so any strategy returns index 2
  let logits : FixedArray[Float] = [0.0, 0.0, 50.0, 0.0, 0.0]
  let rng = @infer.Rng::new(42)
  @test.assert_eq(@infer.sample(logits, 1.0, 0.0, rng), 2)
  @test.assert_eq(@infer.sample(logits, 1.0, 0.9, rng), 2)
}

///|
test "sampling stays in range and is reproducible per seed" {
  let logits : FixedArray[Float] = [1.0, 2.0, 1.5, 0.5, 3.0, 2.5, 0.1, 1.2]
  let a = @infer.Rng::new(123)
  let b = @infer.Rng::new(123)
  for _ in 0..<20 {
    let ta = @infer.sample(logits, 0.8, 0.9, a)
    let tb = @infer.sample(logits, 0.8, 0.9, b)
    @test.assert_eq(ta, tb) // same seed -> same draw
    @test.assert_eq(ta >= 0 && ta < logits.length(), true)
  }
}

///|
test "rng produces floats in [0, 1)" {
  let rng = @infer.Rng::new(7)
  for _ in 0..<100 {
    let r = rng.next_float()
    @test.assert_eq(r >= (0.0 : Float) && r < (1.0 : Float), true)
  }
}
