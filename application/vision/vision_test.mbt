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

// A 3->3->3 identity MLP: hidden = input (relu), out = hidden, so the predicted
// class is just argmax(input). This pins down the int8 forward + argmax wiring.

///|
fn identity3() -> @vision.MLP {
  let id : FixedArray[Byte] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
  @vision.MLP::new(id, id, 3, 3, 3, 0)
}

///|
test "classifies by the strongest feature" {
  let m = identity3()
  @test.assert_eq(m.classify([10, 50, 20]), 1)
  @test.assert_eq(m.classify([5, 5, 99]), 2)
  @test.assert_eq(m.classify([80, 1, 1]), 0)
}

///|
test "logits reflect the input through identity weights" {
  let m = identity3()
  @test.assert_eq(m.logits([7, 3, 11]), [7, 3, 11])
}

///|
test "relu drops negative features before the output layer" {
  let m = identity3()
  // 216 is -40 as signed int8; relu zeroes it, so class 1 (25) wins
  @test.assert_eq(m.classify([3, 25, 216]), 1)
}

///|
test "center maps 0-255 pixels into signed int8" {
  let c = @vision.center([0, 128, 255])
  @test.assert_eq(c[0], (-128).to_byte())
  @test.assert_eq(c[1], (0).to_byte())
  @test.assert_eq(c[2], (127).to_byte())
}
