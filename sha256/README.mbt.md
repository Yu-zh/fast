# `Yu-zh/fast/sha256`

SHA-256 (FIPS 180-4) over `FixedArray[Byte]`, returning a 32-byte digest. This
is a **scalar** reference: the message schedule and compression rounds carry
strict data dependencies, and hardware SHA uses dedicated crypto instructions
(x86 SHA extensions, ARMv8 crypto) rather than general SIMD. The API is stable
for when such intrinsics become available.

```mbt check
///|
test "readme: sha256" {
  let empty : FixedArray[Byte] = []
  let digest = @sha256.hash(empty)
  // SHA-256("") begins with e3 b0 c4 44 ...
  @test.assert_eq(digest.length(), 32)
  @test.assert_eq(digest[0], 0xe3)
  @test.assert_eq(digest[1], 0xb0)
}
```
