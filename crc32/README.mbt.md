# `Yu-zh/fast/crc32`

CRC-32 (IEEE 802.3 — the zlib/gzip variant) over `FixedArray[Byte]`. This is
the classic byte-at-a-time table method and is **scalar**: a SIMD "folding"
CRC needs a carryless multiply (`PCLMULQDQ` / `VMULL`), which `v128` does not
currently expose. When such an intrinsic lands, this is the package to revisit
— the public API would be unchanged.

```mbt check
///|
test "readme: crc32" {
  let data : FixedArray[Byte] = [
    b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9',
  ]
  @test.assert_eq(@crc32.checksum(data), 0xCBF43926U)
}
```
