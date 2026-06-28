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

// `fabs`, `close`, `Rng`, `build`, `copy_f` are shared from the other test
// files in this package's blackbox test scope.

///|
let qgs = 16

///|
fn iround_t(x : Float) -> Int {
  if x >= (0.0 : Float) {
    (x + (0.5 : Float)).to_int()
  } else {
    (x - (0.5 : Float)).to_int()
  }
}

///|
fn to_i8(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 128 {
    v - 256
  } else {
    v
  }
}

///|
/// Scalar reference: quantize a length-n vector into int8 + per-group scales.
fn quant_vec(
  v : FixedArray[Float],
  n : Int,
) -> (FixedArray[Int], FixedArray[Float]) {
  let groups = n / qgs
  let q : FixedArray[Int] = FixedArray::make(n, 0)
  let sc : FixedArray[Float] = FixedArray::make(groups, 0.0)
  for g in 0..<groups {
    let mut amax = (0.0 : Float)
    for i in 0..<qgs {
      let a = fabs(v[g * qgs + i])
      if a > amax {
        amax = a
      }
    }
    let scale = amax / (127.0 : Float)
    sc[g] = scale
    let inv = if scale > (0.0 : Float) {
      (1.0 : Float) / scale
    } else {
      (0.0 : Float)
    }
    for i in 0..<qgs {
      let r = iround_t(v[g * qgs + i] * inv)
      q[g * qgs + i] = if r > 127 { 127 } else if r < -127 { -127 } else { r }
    }
  }
  (q, sc)
}

///|
fn qmatmul_ref(
  xf : FixedArray[Float],
  wf : FixedArray[Float],
  n : Int,
  d : Int,
) -> FixedArray[Float] {
  let (xq, xs) = quant_vec(xf, n)
  let groups = n / qgs
  let out : FixedArray[Float] = FixedArray::make(d, 0.0)
  for i in 0..<d {
    let row : FixedArray[Float] = FixedArray::make(n, 0.0)
    for j in 0..<n {
      row[j] = wf[i * n + j]
    }
    let (wq, ws) = quant_vec(row, n)
    let mut val = (0.0 : Float)
    for g in 0..<groups {
      let mut ival = 0
      for k in 0..<qgs {
        ival = ival + xq[g * qgs + k] * wq[g * qgs + k]
      }
      val = val + Float::from_int(ival) * ws[g] * xs[g]
    }
    out[i] = val
  }
  out
}

///|
test "qmatmul matches the scalar quantized reference exactly" {
  let n = 32
  let d = 7
  let rng = Rng::{ state: 0x51ed2701 }
  let xf : FixedArray[Float] = FixedArray::make(n, 0.0)
  for i in 0..<n {
    xf[i] = rng.next_float()
  }
  let wf : FixedArray[Float] = FixedArray::make(d * n, 0.0)
  for i in 0..<(d * n) {
    wf[i] = rng.next_float()
  }
  let xt = @infer.quantize_matrix(xf, n)
  let wt = @infer.quantize_matrix(wf, d * n)
  let out : FixedArray[Float] = FixedArray::make(d, 0.0)
  @infer.qmatmul(out, xt.q, xt.scales, wt, n, d)
  @test.assert_eq(out, qmatmul_ref(xf, wf, n, d))
}

///|
test "quantize round-trips within the group scale" {
  let v : FixedArray[Float] = FixedArray::make(16, 0.0)
  let rng = Rng::{ state: 0xa5a5 }
  for i in 0..<16 {
    v[i] = rng.next_float()
  }
  let t = @infer.quantize_matrix(v, 16)
  let scale = t.scales[0]
  for i in 0..<16 {
    let dq = Float::from_int(to_i8(t.q[i])) * scale
    @test.assert_eq(fabs(dq - v[i]) <= scale, true)
  }
}

///|
test "quantized forward runs and is deterministic" {
  let c = @infer.Config::{
    dim: 32,
    hidden_dim: 64,
    n_layers: 2,
    n_heads: 4,
    n_kv_heads: 4,
    vocab_size: 48,
    seq_len: 8,
  }
  let w = build(c, 0x1234abcd)
  let m = @infer.QTransformer::new(c, w)
  let a = copy_f(m.forward(1, 0))
  @test.assert_eq(a.length(), 48)
  let m2 = @infer.QTransformer::new(c, w)
  let b = copy_f(m2.forward(1, 0))
  @test.assert_eq(a, b)
}
