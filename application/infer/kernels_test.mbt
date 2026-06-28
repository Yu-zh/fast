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
fn fabs(x : Float) -> Float {
  if x < (0.0 : Float) {
    -x
  } else {
    x
  }
}

///|
fn close(a : Float, b : Float) -> Bool {
  fabs(a - b) < (1.0e-4 : Float)
}

///|
fn arr_close(a : FixedArray[Float], b : FixedArray[Float]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if !close(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
test "matmul (exact for small integers)" {
  let x : FixedArray[Float] = [1.0, 2.0, 3.0]
  // 3 rows of length 3
  let w : FixedArray[Float] = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0]
  let out : FixedArray[Float] = FixedArray::make(3, 0.0)
  @infer.matmul(out, x, w, 3, 3)
  @test.assert_eq(out, [1.0, 2.0, 6.0])
}

///|
test "rmsnorm matches scalar reference" {
  let x : FixedArray[Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
  let weight : FixedArray[Float] = [1.0, 1.0, 1.0, 1.0, 1.0]
  let out : FixedArray[Float] = FixedArray::make(5, 0.0)
  @infer.rmsnorm(out, x, weight, 5)
  let mut ss = 0.0
  for i in 0..<5 {
    ss = ss + x[i].to_double() * x[i].to_double()
  }
  ss = ss / 5.0 + 1.0e-5
  let scale = 1.0 / ss.sqrt()
  let ref_ : FixedArray[Float] = FixedArray::make(5, 0.0)
  for i in 0..<5 {
    ref_[i] = Float::from_double(
      x[i].to_double() * scale * weight[i].to_double(),
    )
  }
  @test.assert_eq(arr_close(out, ref_), true)
}

///|
test "softmax sums to 1 and is monotonic" {
  let x : FixedArray[Float] = [1.0, 2.0, 3.0, 4.0]
  @infer.softmax(x, 0, 4)
  let mut total = (0.0 : Float)
  for i in 0..<4 {
    total = total + x[i]
  }
  @test.assert_eq(close(total, 1.0), true)
  @test.assert_eq(x[0] < x[1] && x[1] < x[2] && x[2] < x[3], true)
}

///|
test "swiglu matches scalar reference" {
  let gate : FixedArray[Float] = [-2.0, -0.5, 0.0, 1.0, 3.0]
  let up : FixedArray[Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
  let ref_ : FixedArray[Float] = FixedArray::make(5, 0.0)
  for i in 0..<5 {
    let v = gate[i].to_double()
    let silu = v / (1.0 + @math.exp(-v))
    ref_[i] = Float::from_double(silu * up[i].to_double())
  }
  @infer.swiglu(gate, up, 5)
  @test.assert_eq(arr_close(gate, ref_), true)
}

///|
test "rope matches scalar reference" {
  let dim = 8
  let head_size = 4
  let kv_dim = 8
  let pos = 3
  let q : FixedArray[Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  let k : FixedArray[Float] = [8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0]
  let qr : FixedArray[Float] = FixedArray::make(dim, 0.0)
  let kr : FixedArray[Float] = FixedArray::make(dim, 0.0)
  for i in 0..<dim {
    qr[i] = q[i]
    kr[i] = k[i]
  }
  let mut i = 0
  while i < dim {
    let head_dim = i % head_size
    let freq = 1.0 /
      @math.pow(10000.0, head_dim.to_double() / head_size.to_double())
    let val = pos.to_double() * freq
    let fcr = @math.cos(val)
    let fci = @math.sin(val)
    for which in 0..<2 {
      let vec = if which == 0 { qr } else { kr }
      let v0 = vec[i].to_double()
      let v1 = vec[i + 1].to_double()
      vec[i] = Float::from_double(v0 * fcr - v1 * fci)
      vec[i + 1] = Float::from_double(v0 * fci + v1 * fcr)
    }
    i = i + 2
  }
  @infer.rope(q, k, pos, dim, kv_dim, head_size)
  @test.assert_eq(arr_close(q, qr) && arr_close(k, kr), true)
}
