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
test "classify picks the highest-logit class (cross-module to Yu-zh/fast)" {
  let input : FixedArray[Byte] = [1, 2, 3] // one sample, 3 features
  // 3 classes x 3 features (each row is a class weight vector)
  let weights : FixedArray[Byte] = [1, 0, 0, 0, 1, 1, 0, 0, 0]
  // logits = [1*1, 2*1+3*1, 0] = [1, 5, 0] -> class 1
  @test.assert_eq(@infer.classify(input, weights, 3, 3), 1)
}
