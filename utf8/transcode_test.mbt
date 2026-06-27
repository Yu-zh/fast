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
/// Reference UTF-8 encoder over a code point list.
fn encode_utf8(cps : Array[Int]) -> FixedArray[Byte] {
  let buf : Array[Byte] = []
  for cp in cps {
    if cp < 0x80 {
      buf.push(cp.to_byte())
    } else if cp < 0x800 {
      buf.push((0xc0 | (cp >> 6)).to_byte())
      buf.push((0x80 | (cp & 0x3f)).to_byte())
    } else if cp < 0x10000 {
      buf.push((0xe0 | (cp >> 12)).to_byte())
      buf.push((0x80 | ((cp >> 6) & 0x3f)).to_byte())
      buf.push((0x80 | (cp & 0x3f)).to_byte())
    } else {
      buf.push((0xf0 | (cp >> 18)).to_byte())
      buf.push((0x80 | ((cp >> 12) & 0x3f)).to_byte())
      buf.push((0x80 | ((cp >> 6) & 0x3f)).to_byte())
      buf.push((0x80 | (cp & 0x3f)).to_byte())
    }
  }
  let out : FixedArray[Byte] = FixedArray::make(buf.length(), 0)
  for i in 0..<buf.length() {
    out[i] = buf[i]
  }
  out
}

///|
/// Reference UTF-16LE encoder over a code point list.
fn encode_utf16le(cps : Array[Int]) -> FixedArray[Byte] {
  let buf : Array[Byte] = []
  fn unit(u : Int) {
    buf.push(u.to_byte())
    buf.push((u >> 8).to_byte())
  }

  for cp in cps {
    if cp < 0x10000 {
      unit(cp)
    } else {
      let v = cp - 0x10000
      unit(0xd800 | (v >> 10))
      unit(0xdc00 | (v & 0x3ff))
    }
  }
  let out : FixedArray[Byte] = FixedArray::make(buf.length(), 0)
  for i in 0..<buf.length() {
    out[i] = buf[i]
  }
  out
}

///|
fn check_round_trip(cps : Array[Int], msg~ : String) -> Unit raise {
  let utf8 = encode_utf8(cps)
  let utf16 = encode_utf16le(cps)
  @test.assert_eq(@utf8.convert_utf8_to_utf16le(utf8), Some(utf16), msg~)
  @test.assert_eq(@utf8.convert_utf16le_to_utf8(utf16), Some(utf8), msg~)
  @test.assert_eq(@utf8.utf16_length_from_utf8(utf8) * 2, utf16.length(), msg~)
  @test.assert_eq(@utf8.utf8_length_from_utf16le(utf16), utf8.length(), msg~)
  assert_true(@utf8.validate_utf16le(utf16))
}

///|
test "round trips across width classes" {
  check_round_trip([], msg="empty")
  check_round_trip([0x48, 0x69], msg="ascii")
  // every width class and its boundaries
  check_round_trip(
    [
      0x00, 0x7f, 0x80, 0x7ff, 0x800, 0xd7ff, 0xe000, 0xfffd, 0xffff, 0x10000, 0x1f389,
      0x10ffff,
    ],
    msg="boundaries",
  )
  // long ASCII run with multibyte interruptions at varying offsets
  for offset in 0..<24 {
    let cps : Array[Int] = []
    for j in 0..<48 {
      cps.push(if j == offset { 0x1f600 } else { 0x61 })
    }
    check_round_trip(cps, msg="emoji at \{offset}")
  }
}

///|
test "randomized round trips" {
  let mut state = 0xc0ffee11U
  fn next() -> UInt {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state
  }

  for round in 0..<60 {
    let count = (next() % 120).reinterpret_as_int()
    let cps : Array[Int] = []
    for _ in 0..<count {
      let cp = match (next() % 5).reinterpret_as_int() {
        0 => (next() % 0x80).reinterpret_as_int()
        1 => 0x80 + (next() % 0x780).reinterpret_as_int()
        2 => 0x800 + (next() % 0xd000).reinterpret_as_int()
        3 => 0xe000 + (next() % 0x2000).reinterpret_as_int()
        _ => 0x10000 + (next() % 0x100000).reinterpret_as_int()
      }
      cps.push(cp)
    }
    check_round_trip(cps, msg="round \{round}")
  }
}

///|
test "validate_utf16le" {
  // valid: empty, BMP, exact pair
  assert_true(@utf8.validate_utf16le(FixedArray::make(0, b'\x00')))
  assert_true(@utf8.validate_utf16le(encode_utf16le([0x48, 0xffff, 0x1f389])))
  // odd length
  assert_false(@utf8.validate_utf16le([0x41]))
  // lone high, lone low, reversed pair, double high
  assert_false(@utf8.validate_utf16le([0x00, 0xd8]))
  assert_false(@utf8.validate_utf16le([0x00, 0xdc]))
  assert_false(@utf8.validate_utf16le([0x00, 0xdc, 0x00, 0xd8]))
  assert_false(@utf8.validate_utf16le([0x00, 0xd8, 0x00, 0xd8]))
  // high surrogate at the very end after valid content
  let mut units : Array[Int] = []
  for _ in 0..<9 {
    units.push(0x41)
  }
  units.push(0xd800)
  assert_false(@utf8.validate_utf16le(encode_raw_units(units)))
  // a pair straddling every block boundary position
  for pad in 0..<18 {
    units = []
    for _ in 0..<pad {
      units.push(0x41)
    }
    units.push(0xd83c)
    units.push(0xdf89)
    units.push(0x42)
    assert_true(@utf8.validate_utf16le(encode_raw_units(units)))
    // and the same with the low half corrupted
    units[pad + 1] = 0x42
    assert_false(@utf8.validate_utf16le(encode_raw_units(units)))
  }
}

///|
/// Encodes raw 16-bit units without surrogate interpretation, so invalid
/// sequences can be constructed.
fn encode_raw_units(units : Array[Int]) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(units.length() * 2, 0)
  for i in 0..<units.length() {
    out[i * 2] = units[i].to_byte()
    out[i * 2 + 1] = (units[i] >> 8).to_byte()
  }
  out
}

///|
test "fused validation agrees with the validators" {
  let mut state = 0xfeedf00dU
  fn next() -> UInt {
    state = state ^ (state << 13)
    state = state ^ (state >> 17)
    state = state ^ (state << 5)
    state
  }

  // byte soups biased towards UTF-8 lead/continuation bytes: conversion
  // must succeed exactly when validate() accepts
  for _ in 0..<300 {
    let len = (next() % 90).reinterpret_as_int()
    let bytes : FixedArray[Byte] = FixedArray::make(len, 0)
    for i in 0..<len {
      let r = next() % 10
      bytes[i] = if r < 4 {
        (next() % 0x80).to_byte()
      } else {
        (0x80U + next() % 0x80).to_byte()
      }
    }
    @test.assert_eq(
      @utf8.convert_utf8_to_utf16le(bytes) is Some(_),
      @utf8.validate(bytes),
    )
  }
  // unit soups biased towards surrogates: conversion must succeed exactly
  // when validate_utf16le() accepts
  for _ in 0..<300 {
    let count = (next() % 40).reinterpret_as_int()
    let units : Array[Int] = []
    for _ in 0..<count {
      let r = next() % 10
      units.push(
        if r < 5 {
          (next() % 0xd800).reinterpret_as_int()
        } else {
          0xd800 + (next() % 0x800).reinterpret_as_int()
        },
      )
    }
    let raw = encode_raw_units(units)
    @test.assert_eq(
      @utf8.convert_utf16le_to_utf8(raw) is Some(_),
      @utf8.validate_utf16le(raw),
    )
  }
}

///|
test "converters reject invalid input" {
  // invalid UTF-8 in
  @test.assert_eq(@utf8.convert_utf8_to_utf16le([0xff]), None)
  @test.assert_eq(@utf8.convert_utf8_to_utf16le([0xc3]), None)
  @test.assert_eq(@utf8.convert_utf8_to_utf16le([0xed, 0xa0, 0x80]), None)
  // invalid UTF-16LE in: lone high surrogate, odd length
  @test.assert_eq(
    @utf8.convert_utf16le_to_utf8(encode_raw_units([0x41, 0xd800, 0x42])),
    None,
  )
  @test.assert_eq(@utf8.convert_utf16le_to_utf8([0x41]), None)
}
