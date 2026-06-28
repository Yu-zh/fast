# `Yu-zh/fast/vsearch`

Vector similarity search — the distance kernels under semantic search / RAG.
The float metrics (`dot`, `l2_squared`, `cosine`) work over `FixedArray[Float]`
(f32, four lanes per vector op); binary vectors use `hamming`, computed with
`v128_xor` + `i8x16_popcnt`. `top_k_cosine` is a brute-force nearest-neighbour
scan that keeps the best k as it goes. Floating-point results are
lane-partitioned, so they may differ from a strict sequential sum by rounding.

```mbt check
///|
test "readme: vsearch" {
  let a : FixedArray[Float] = [1.0, 2.0, 2.0]
  let b : FixedArray[Float] = [2.0, 4.0, 4.0]
  @test.assert_eq(@vsearch.cosine(a, b), 1.0) // parallel vectors
  let query : FixedArray[Float] = [1.0, 0.0, 0.0]
  let corpus : Array[FixedArray[Float]] = [
    [0.0, 1.0, 0.0], // orthogonal
    [2.0, 0.0, 0.0], // parallel — most similar
    [1.0, 1.0, 0.0], // 45 degrees
  ]
  let top = @vsearch.top_k_cosine(query, corpus, 1)
  let (idx, _) = top[0]
  @test.assert_eq(idx, 1)
}
```
