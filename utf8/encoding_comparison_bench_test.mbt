// Tracks the gap against core's encoding/utf8, whose decode/encode
// lower to simdutf-backed runtime intrinsics on non-js backends.

///|
fn transcode_ascii() -> FixedArray[Byte] {
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, 0)
  let mut state = 0x9e3779b9U
  for i in 0..<BENCH_LEN {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    bytes[i] = (0x20U + (state & 0x3f)).to_byte()
  }
  bytes
}

///|
/// ~10% multibyte text: ASCII with CJK and emoji sprinkled in, the shape
/// of typical web content.
fn transcode_mixed() -> FixedArray[Byte] {
  let pattern : FixedArray[Byte] = [
    b'l', b'o', b'r', b'e', b'm', b' ', b'i', b'p', b's', b'u', b'm', b' ', b'd',
    b'o', b'l', b'o', b'r', b' ', b's', b'i', b't', b' ', b'a', b'm', b'e', b't',
    b' ', 0xe4, 0xbd, 0xa0, 0xe5, 0xa5, 0xbd, b' ', 0xf0, 0x9f, 0x8e, 0x89, b' ',
  ]
  let bytes : FixedArray[Byte] = FixedArray::make(BENCH_LEN, b' ')
  let mut i = 0
  while i + pattern.length() <= BENCH_LEN {
    for j in 0..<pattern.length() {
      bytes[i + j] = pattern[j]
    }
    i = i + pattern.length()
  }
  bytes
}

///|
fn as_utf16(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  @utf8.convert_utf8_to_utf16le(bytes).unwrap()
}

///|
fn to_bytes(arr : FixedArray[Byte]) -> Bytes {
  Bytes::makei(arr.length(), i => arr[i])
}

///|
test "bench core decode ascii 64k" (it : @bench.T) {
  let bytes = to_bytes(transcode_ascii())
  it.bench(fn() { it.keep(try! @encutf8.decode(bytes)) })
}

///|
test "bench fast convert ascii 64k" (it : @bench.T) {
  let bytes = transcode_ascii()
  it.bench(fn() { it.keep(@utf8.convert_utf8_to_utf16le(bytes)) })
}

///|
test "bench core decode mixed 64k" (it : @bench.T) {
  let bytes = to_bytes(transcode_mixed())
  it.bench(fn() { it.keep(try! @encutf8.decode(bytes)) })
}

///|
test "bench fast convert mixed 64k" (it : @bench.T) {
  let bytes = transcode_mixed()
  it.bench(fn() { it.keep(@utf8.convert_utf8_to_utf16le(bytes)) })
}

///|
test "bench core encode ascii to utf8" (it : @bench.T) {
  let s = try! @encutf8.decode(to_bytes(transcode_ascii()))
  it.bench(fn() { it.keep(@encutf8.encode(s)) })
}

///|
test "bench fast convert ascii to utf8" (it : @bench.T) {
  let utf16 = as_utf16(transcode_ascii())
  it.bench(fn() { it.keep(@utf8.convert_utf16le_to_utf8(utf16)) })
}

///|
test "bench core encode mixed to utf8" (it : @bench.T) {
  let s = try! @encutf8.decode(to_bytes(transcode_mixed()))
  it.bench(fn() { it.keep(@encutf8.encode(s)) })
}

///|
test "bench fast convert mixed to utf8" (it : @bench.T) {
  let utf16 = as_utf16(transcode_mixed())
  it.bench(fn() { it.keep(@utf8.convert_utf16le_to_utf8(utf16)) })
}
