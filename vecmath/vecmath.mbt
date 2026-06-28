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

// Light vector math over `FixedArray[Double]`. Lanes are gathered with
// `f64x2_const` (there is no vector load for typed arrays) and combined two at
// a time. `dot` and the arg-reductions need no per-element stores, so they get
// the most from the vector arithmetic; `axpy` / `scale` compute two lanes at a
// time but write results back element-wise. Floating-point results can differ
// from a strict sequential evaluation by rounding.

///|
fn load2(a : FixedArray[Double], i : Int) -> V128 {
  @v128.f64x2_const(a[i], a[i + 1])
}

///|
fn dmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn dmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn minimum(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Returns the dot product of `a` and `b` over their common prefix.
pub fn dot(a : FixedArray[Double], b : FixedArray[Double]) -> Double {
  let n = minimum(a.length(), b.length())
  let mut acc = @v128.f64x2_splat(0.0)
  let mut i = 0
  while i + 2 <= n {
    acc = @v128.f64x2_add(acc, @v128.f64x2_mul(load2(a, i), load2(b, i)))
    i = i + 2
  }
  let mut total = @v128.f64x2_extract_lane(acc, 0) +
    @v128.f64x2_extract_lane(acc, 1)
  while i < n {
    total = total + a[i] * b[i]
    i = i + 1
  }
  total
}

///|
/// In place, sets `y[i] = alpha * x[i] + y[i]` over their common prefix.
pub fn axpy(
  alpha : Double,
  x : FixedArray[Double],
  y : FixedArray[Double],
) -> Unit {
  let n = minimum(x.length(), y.length())
  let a = @v128.f64x2_splat(alpha)
  let mut i = 0
  while i + 2 <= n {
    let r = @v128.f64x2_add(@v128.f64x2_mul(a, load2(x, i)), load2(y, i))
    y[i] = @v128.f64x2_extract_lane(r, 0)
    y[i + 1] = @v128.f64x2_extract_lane(r, 1)
    i = i + 2
  }
  while i < n {
    y[i] = alpha * x[i] + y[i]
    i = i + 1
  }
}

///|
/// In place, multiplies every element of `x` by `alpha`.
pub fn scale(alpha : Double, x : FixedArray[Double]) -> Unit {
  let n = x.length()
  let a = @v128.f64x2_splat(alpha)
  let mut i = 0
  while i + 2 <= n {
    let r = @v128.f64x2_mul(a, load2(x, i))
    x[i] = @v128.f64x2_extract_lane(r, 0)
    x[i + 1] = @v128.f64x2_extract_lane(r, 1)
    i = i + 2
  }
  while i < n {
    x[i] = alpha * x[i]
    i = i + 1
  }
}

///|
/// Returns the index of the first minimum element, or `None` if empty.
pub fn argmin(a : FixedArray[Double]) -> Int? {
  let n = a.length()
  if n == 0 {
    return None
  }
  let mut acc = @v128.f64x2_splat(a[0])
  let mut i = 0
  while i + 2 <= n {
    acc = @v128.f64x2_min(acc, load2(a, i))
    i = i + 2
  }
  let mut best = dmin(
    @v128.f64x2_extract_lane(acc, 0),
    @v128.f64x2_extract_lane(acc, 1),
  )
  while i < n {
    best = dmin(best, a[i])
    i = i + 1
  }
  for j in 0..<n {
    if a[j] == best {
      return Some(j)
    }
  }
  None
}

///|
/// Returns the index of the first maximum element, or `None` if empty.
pub fn argmax(a : FixedArray[Double]) -> Int? {
  let n = a.length()
  if n == 0 {
    return None
  }
  let mut acc = @v128.f64x2_splat(a[0])
  let mut i = 0
  while i + 2 <= n {
    acc = @v128.f64x2_max(acc, load2(a, i))
    i = i + 2
  }
  let mut best = dmax(
    @v128.f64x2_extract_lane(acc, 0),
    @v128.f64x2_extract_lane(acc, 1),
  )
  while i < n {
    best = dmax(best, a[i])
    i = i + 1
  }
  for j in 0..<n {
    if a[j] == best {
      return Some(j)
    }
  }
  None
}
