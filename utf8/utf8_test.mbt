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
fn is_cont(b : Byte) -> Bool {
  b >= 0x80 && b <= 0xbf
}

///|
/// Straightforward scalar validator following RFC 3629 (table-driven range
/// checks per lead byte), used as the reference implementation.
fn validate_scalar(bytes : FixedArray[Byte]) -> Bool {
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let b = bytes[i]
    if b < 0x80 {
      i = i + 1
    } else if b < 0xc2 {
      // continuation byte or overlong 2-byte lead (C0/C1)
      return false
    } else if b < 0xe0 {
      if i + 1 >= len || !is_cont(bytes[i + 1]) {
        return false
      }
      i = i + 2
    } else if b < 0xf0 {
      if i + 2 >= len {
        return false
      }
      let b1 = bytes[i + 1]
      let lo : Byte = if b == 0xe0 { 0xa0 } else { 0x80 }
      let hi : Byte = if b == 0xed { 0x9f } else { 0xbf }
      if b1 < lo || b1 > hi || !is_cont(bytes[i + 2]) {
        return false
      }
      i = i + 3
    } else if b < 0xf5 {
      if i + 3 >= len {
        return false
      }
      let b1 = bytes[i + 1]
      let lo : Byte = if b == 0xf0 { 0x90 } else { 0x80 }
      let hi : Byte = if b == 0xf4 { 0x8f } else { 0xbf }
      if b1 < lo || b1 > hi || !is_cont(bytes[i + 2]) || !is_cont(bytes[i + 3]) {
        return false
      }
      i = i + 4
    } else {
      return false
    }
  }
  true
}

///|
test "targeted valid sequences" {
  assert_true(@utf8.validate(FixedArray::make(0, b'\x00')))
  assert_true(@utf8.validate([b'h', b'i']))
  // U+00E9 é, U+07FF, U+0800, U+D7FF, U+E000, U+FFFD, U+10000, U+10FFFF
  assert_true(@utf8.validate([0xc3, 0xa9]))
  assert_true(@utf8.validate([0xdf, 0xbf]))
  assert_true(@utf8.validate([0xe0, 0xa0, 0x80]))
  assert_true(@utf8.validate([0xed, 0x9f, 0xbf]))
  assert_true(@utf8.validate([0xee, 0x80, 0x80]))
  assert_true(@utf8.validate([0xef, 0xbf, 0xbd]))
  assert_true(@utf8.validate([0xf0, 0x90, 0x80, 0x80]))
  assert_true(@utf8.validate([0xf4, 0x8f, 0xbf, 0xbf]))
  // mixed text: "héllo wörld 你好 🎉"
  assert_true(
    @utf8.validate([
      b'h', 0xc3, 0xa9, b'l', b'l', b'o', b' ', b'w', 0xc3, 0xb6, b'r', b'l', b'd',
      b' ', 0xe4, 0xbd, 0xa0, 0xe5, 0xa5, 0xbd, b' ', 0xf0, 0x9f, 0x8e, 0x89,
    ]),
  )
}

///|
test "targeted invalid sequences" {
  // lone continuation, bare lead bytes, truncations
  assert_false(@utf8.validate([0x80]))
  assert_false(@utf8.validate([0xbf]))
  assert_false(@utf8.validate([0xc3]))
  assert_false(@utf8.validate([0xe0, 0xa0]))
  assert_false(@utf8.validate([0xf0, 0x90, 0x80]))
  assert_false(@utf8.validate([b'a', 0xc3]))
  // overlong encodings
  assert_false(@utf8.validate([0xc0, 0x80]))
  assert_false(@utf8.validate([0xc1, 0xbf]))
  assert_false(@utf8.validate([0xe0, 0x80, 0x80]))
  assert_false(@utf8.validate([0xe0, 0x9f, 0xbf]))
  assert_false(@utf8.validate([0xf0, 0x80, 0x80, 0x80]))
  assert_false(@utf8.validate([0xf0, 0x8f, 0xbf, 0xbf]))
  // surrogates U+D800..U+DFFF
  assert_false(@utf8.validate([0xed, 0xa0, 0x80]))
  assert_false(@utf8.validate([0xed, 0xbf, 0xbf]))
  // above U+10FFFF and invalid lead bytes
  assert_false(@utf8.validate([0xf4, 0x90, 0x80, 0x80]))
  assert_false(@utf8.validate([0xf5, 0x80, 0x80, 0x80]))
  assert_false(@utf8.validate([0xfe]))
  assert_false(@utf8.validate([0xff]))
  // continuation after a complete sequence
  assert_false(@utf8.validate([0xc3, 0xa9, 0x80]))
  // missing continuation in the middle
  assert_false(@utf8.validate([0xe4, 0xbd, b'x']))
}

///|
test "exhaustive two-byte cross-check" {
  let bytes : FixedArray[Byte] = FixedArray::make(2, 0)
  for a in 0..<256 {
    for b in 0..<256 {
      bytes[0] = a.to_byte()
      bytes[1] = b.to_byte()
      let expected = validate_scalar(bytes)
      if @utf8.validate(bytes) != expected {
        @test.fail("mismatch for [\{a}, \{b}]: expected \{expected}")
      }
    }
  }
}

///|
test "boundary-value three and four byte cross-check" {
  let probes : FixedArray[Byte] = [
    0x00, 0x7f, 0x80, 0x8f, 0x90, 0x9f, 0xa0, 0xbf, 0xc0, 0xff,
  ]
  let bytes3 : FixedArray[Byte] = FixedArray::make(3, 0)
  for lead in ([0xe0, 0xe1, 0xec, 0xed, 0xee, 0xef] : FixedArray[Byte]) {
    for b1 in probes {
      for b2 in probes {
        bytes3[0] = lead
        bytes3[1] = b1
        bytes3[2] = b2
        let expected = validate_scalar(bytes3)
        if @utf8.validate(bytes3) != expected {
          @test.fail("mismatch for [\{lead}, \{b1}, \{b2}]")
        }
      }
    }
  }
  let bytes4 : FixedArray[Byte] = FixedArray::make(4, 0)
  for lead in ([0xf0, 0xf1, 0xf3, 0xf4] : FixedArray[Byte]) {
    for b1 in probes {
      for b2 in probes {
        for b3 in probes {
          bytes4[0] = lead
          bytes4[1] = b1
          bytes4[2] = b2
          bytes4[3] = b3
          let expected = validate_scalar(bytes4)
          if @utf8.validate(bytes4) != expected {
            @test.fail("mismatch for [\{lead}, \{b1}, \{b2}, \{b3}]")
          }
        }
      }
    }
  }
}

///|
test "sequences across block boundaries" {
  // a 4-byte emoji slid through every offset of a 64-byte buffer
  for pos in 0..<61 {
    let bytes : FixedArray[Byte] = FixedArray::make(64, b'a')
    bytes[pos] = 0xf0
    bytes[pos + 1] = 0x9f
    bytes[pos + 2] = 0x8e
    bytes[pos + 3] = 0x89
    assert_true(@utf8.validate(bytes))
    // and with its last byte corrupted
    bytes[pos + 3] = b'x'
    assert_false(@utf8.validate(bytes))
  }
  // truncated lead at the very end of buffers of every small size
  for len in 1..<40 {
    let bytes : FixedArray[Byte] = FixedArray::make(len, b'a')
    bytes[len - 1] = 0xe4
    assert_false(@utf8.validate(bytes))
  }
}

///|
test "randomized cross-check" {
  let mut state = 0x12345678U
  fn next() -> UInt {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state
  }

  for _ in 0..<300 {
    let len = (next() % 80).reinterpret_as_int() + 1
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    // biased towards interesting bytes: mostly valid UTF-8 fragments with
    // occasional corruption
    let mut i = 0
    while i < len {
      let r = next() % 100
      if r < 55 {
        bytes[i] = (next() % 0x80).to_byte()
        i = i + 1
      } else if r < 70 && i + 1 < len {
        bytes[i] = (0xc2U + next() % 30).to_byte()
        bytes[i + 1] = (0x80U + next() % 0x40).to_byte()
        i = i + 2
      } else if r < 85 && i + 2 < len {
        bytes[i] = (0xe0U + next() % 16).to_byte()
        bytes[i + 1] = (0x80U + next() % 0x40).to_byte()
        bytes[i + 2] = (0x80U + next() % 0x40).to_byte()
        i = i + 3
      } else {
        bytes[i] = (next() % 256).to_byte()
        i = i + 1
      }
    }
    @test.assert_eq(@utf8.validate(bytes), validate_scalar(bytes))
  }
}
