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

// A fully independent f64 scalar reference for the Llama forward pass, used to
// cross-check the SIMD (f32) implementation end to end — catching any KV-cache,
// head/GQA, RoPE, or residual indexing mistakes.

///|
struct Rng {
  mut state : UInt
}

///|
fn Rng::next_float(self : Rng) -> Float {
  self.state = self.state ^ (self.state << 13)
  self.state = self.state ^ (self.state >> 17)
  self.state = self.state ^ (self.state << 5)
  Float::from_int((self.state % 1000U).reinterpret_as_int() - 500) /
  (500.0 : Float)
}

///|
fn Rng::arr(self : Rng, n : Int) -> FixedArray[Float] {
  let a : FixedArray[Float] = FixedArray::make(n, 0.0)
  for i in 0..<n {
    a[i] = self.next_float()
  }
  a
}

///|
fn Rng::layers(self : Rng, count : Int, n : Int) -> Array[FixedArray[Float]] {
  let out : Array[FixedArray[Float]] = []
  for _ in 0..<count {
    out.push(self.arr(n))
  }
  out
}

///|
fn build(c : @infer.Config, seed : UInt) -> @infer.Weights {
  let dim = c.dim
  let kv_dim = dim * c.n_kv_heads / c.n_heads
  let rng = Rng::{ state: seed }
  @infer.Weights::{
    token_embedding: rng.arr(c.vocab_size * dim),
    rms_att: rng.layers(c.n_layers, dim),
    wq: rng.layers(c.n_layers, dim * dim),
    wk: rng.layers(c.n_layers, kv_dim * dim),
    wv: rng.layers(c.n_layers, kv_dim * dim),
    wo: rng.layers(c.n_layers, dim * dim),
    rms_ffn: rng.layers(c.n_layers, dim),
    w1: rng.layers(c.n_layers, c.hidden_dim * dim),
    w2: rng.layers(c.n_layers, dim * c.hidden_dim),
    w3: rng.layers(c.n_layers, c.hidden_dim * dim),
    rms_final: rng.arr(dim),
    wcls: rng.arr(c.vocab_size * dim),
  }
}

// --- f64 scalar reference -------------------------------------------------

///|
fn matvec_ref(
  x : FixedArray[Double],
  w : FixedArray[Float],
  n : Int,
  d : Int,
) -> FixedArray[Double] {
  let out : FixedArray[Double] = FixedArray::make(d, 0.0)
  for i in 0..<d {
    let mut s = 0.0
    for j in 0..<n {
      s = s + w[i * n + j].to_double() * x[j]
    }
    out[i] = s
  }
  out
}

///|
fn rmsnorm_ref(
  x : FixedArray[Double],
  weight : FixedArray[Float],
  size : Int,
) -> FixedArray[Double] {
  let mut ss = 0.0
  for j in 0..<size {
    ss = ss + x[j] * x[j]
  }
  ss = ss / size.to_double() + 1.0e-5
  let scale = 1.0 / ss.sqrt()
  let out : FixedArray[Double] = FixedArray::make(size, 0.0)
  for j in 0..<size {
    out[j] = x[j] * scale * weight[j].to_double()
  }
  out
}

///|
fn softmax_ref(a : FixedArray[Double], size : Int) -> Unit {
  let mut m = a[0]
  for i in 1..<size {
    if a[i] > m {
      m = a[i]
    }
  }
  let mut sum = 0.0
  for i in 0..<size {
    let e = @math.exp(a[i] - m)
    a[i] = e
    sum = sum + e
  }
  for i in 0..<size {
    a[i] = a[i] / sum
  }
}

///|
fn rope_ref(
  q : FixedArray[Double],
  k : FixedArray[Double],
  pos : Int,
  dim : Int,
  kv_dim : Int,
  head_size : Int,
) -> Unit {
  let mut i = 0
  while i < dim {
    let head_dim = i % head_size
    let freq = 1.0 /
      @math.pow(10000.0, head_dim.to_double() / head_size.to_double())
    let val = pos.to_double() * freq
    let fcr = @math.cos(val)
    let fci = @math.sin(val)
    let rotn = if i < kv_dim { 2 } else { 1 }
    for v in 0..<rotn {
      let vec = if v == 0 { q } else { k }
      let v0 = vec[i]
      let v1 = vec[i + 1]
      vec[i] = v0 * fcr - v1 * fci
      vec[i + 1] = v0 * fci + v1 * fcr
    }
    i = i + 2
  }
}

///|
fn forward_ref(
  c : @infer.Config,
  w : @infer.Weights,
  token : Int,
  pos : Int,
  kcache : FixedArray[Double],
  vcache : FixedArray[Double],
) -> FixedArray[Double] {
  let dim = c.dim
  let head_size = dim / c.n_heads
  let kv_dim = dim * c.n_kv_heads / c.n_heads
  let kv_mul = c.n_heads / c.n_kv_heads
  let x : FixedArray[Double] = FixedArray::make(dim, 0.0)
  for i in 0..<dim {
    x[i] = w.token_embedding[token * dim + i].to_double()
  }
  for l in 0..<c.n_layers {
    let xb = rmsnorm_ref(x, w.rms_att[l], dim)
    let q = matvec_ref(xb, w.wq[l], dim, dim)
    let kk = matvec_ref(xb, w.wk[l], dim, kv_dim)
    let vv = matvec_ref(xb, w.wv[l], dim, kv_dim)
    rope_ref(q, kk, pos, dim, kv_dim, head_size)
    let loff = l * c.seq_len * kv_dim
    for i in 0..<kv_dim {
      kcache[loff + pos * kv_dim + i] = kk[i]
      vcache[loff + pos * kv_dim + i] = vv[i]
    }
    let xba : FixedArray[Double] = FixedArray::make(dim, 0.0)
    for h in 0..<c.n_heads {
      let qoff = h * head_size
      let head_off = h / kv_mul * head_size
      let att : FixedArray[Double] = FixedArray::make(pos + 1, 0.0)
      for t in 0..<=pos {
        let mut sc = 0.0
        for i in 0..<head_size {
          sc = sc + q[qoff + i] * kcache[loff + t * kv_dim + head_off + i]
        }
        att[t] = sc / head_size.to_double().sqrt()
      }
      softmax_ref(att, pos + 1)
      for t in 0..<=pos {
        let a = att[t]
        for i in 0..<head_size {
          xba[qoff + i] = xba[qoff + i] +
            a * vcache[loff + t * kv_dim + head_off + i]
        }
      }
    }
    let xb2 = matvec_ref(xba, w.wo[l], dim, dim)
    for i in 0..<dim {
      x[i] = x[i] + xb2[i]
    }
    let xf = rmsnorm_ref(x, w.rms_ffn[l], dim)
    let hb = matvec_ref(xf, w.w1[l], dim, c.hidden_dim)
    let hb2 = matvec_ref(xf, w.w3[l], dim, c.hidden_dim)
    for i in 0..<c.hidden_dim {
      let v = hb[i]
      hb[i] = v / (1.0 + @math.exp(-v)) * hb2[i]
    }
    let down = matvec_ref(hb, w.w2[l], c.hidden_dim, dim)
    for i in 0..<dim {
      x[i] = x[i] + down[i]
    }
  }
  let xfin = rmsnorm_ref(x, w.rms_final, dim)
  matvec_ref(xfin, w.wcls, dim, c.vocab_size)
}

///|
fn argmax_f(a : FixedArray[Float]) -> Int {
  let mut best = 0
  for i in 1..<a.length() {
    if a[i] > a[best] {
      best = i
    }
  }
  best
}

///|
fn argmax_d(a : FixedArray[Double]) -> Int {
  let mut best = 0
  for i in 1..<a.length() {
    if a[i] > a[best] {
      best = i
    }
  }
  best
}

///|
fn copy_f(a : FixedArray[Float]) -> FixedArray[Float] {
  let out : FixedArray[Float] = FixedArray::make(a.length(), 0.0)
  for i in 0..<a.length() {
    out[i] = a[i]
  }
  out
}

///|
fn check_against_reference(c : @infer.Config) -> Unit raise {
  let weights = build(c, 0x9e3779b9)
  let model = @infer.Transformer::new(c, weights)
  let kv_dim = c.dim * c.n_kv_heads / c.n_heads
  let kcache : FixedArray[Double] = FixedArray::make(
    c.n_layers * c.seq_len * kv_dim,
    0.0,
  )
  let vcache : FixedArray[Double] = FixedArray::make(
    c.n_layers * c.seq_len * kv_dim,
    0.0,
  )
  for pos in 0..<5 {
    let token = (pos * 3 + 1) % c.vocab_size
    let simd = copy_f(model.forward(token, pos))
    let ref_ = forward_ref(c, weights, token, pos, kcache, vcache)
    // the argmax (the generated token) must agree
    @test.assert_eq(argmax_f(simd), argmax_d(ref_))
  }
}

///|
test "forward matches f64 reference (multi-head attention)" {
  check_against_reference(@infer.Config::{
    dim: 8,
    hidden_dim: 16,
    n_layers: 2,
    n_heads: 2,
    n_kv_heads: 2,
    vocab_size: 16,
    seq_len: 8,
  })
}

///|
test "forward matches f64 reference (grouped-query attention)" {
  check_against_reference(@infer.Config::{
    dim: 12,
    hidden_dim: 32,
    n_layers: 2,
    n_heads: 3,
    n_kv_heads: 1,
    vocab_size: 24,
    seq_len: 8,
  })
}

///|
test "forward is deterministic" {
  let c = @infer.Config::{
    dim: 8,
    hidden_dim: 16,
    n_layers: 1,
    n_heads: 2,
    n_kv_heads: 2,
    vocab_size: 16,
    seq_len: 8,
  }
  let w = build(c, 0x12345)
  let m1 = @infer.Transformer::new(c, w)
  let m2 = @infer.Transformer::new(c, w)
  let a = copy_f(m1.forward(3, 0))
  let b = copy_f(m2.forward(3, 0))
  @test.assert_eq(a, b)
}
