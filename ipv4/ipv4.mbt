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

// IPv4 dotted-quad parsing and formatting. The whole address (at most 15
// bytes) is loaded into one vector; `i8x16_bitmask` then yields the dot and
// digit position masks in one shot, structure is checked against them, and the
// three dot offsets are recovered with `ctz`. Each octet is short, so its
// value is accumulated scalar. (A fully branchless SIMD parse a la Lemire
// needs a large shuffle table keyed on the dot pattern; this keeps the
// classification vectorized without it.)

///|
/// Parses one octet in `[start, end)` to 0-255, or -1 if malformed. The bytes
/// are already known to be ASCII digits; this checks width, range, and
/// rejects leading zeros.
fn octet(bytes : FixedArray[Byte], start : Int, end : Int) -> Int {
  let len = end - start
  if len < 1 || len > 3 {
    return -1
  }
  if len > 1 && bytes[start] == b'0' {
    return -1
  }
  let mut value = 0
  for i in start..<end {
    value = value * 10 + (bytes[i] - b'0').to_int()
  }
  if value > 255 {
    -1
  } else {
    value
  }
}

///|
/// Parses a dotted-quad IPv4 string into a big-endian `UInt`
/// (`a<<24 | b<<16 | c<<8 | d`), or `None` if malformed.
pub fn parse(bytes : FixedArray[Byte]) -> UInt? {
  let n = bytes.length()
  // "0.0.0.0" (7) .. "255.255.255.255" (15)
  if n < 7 || n > 15 {
    return None
  }
  let buf : FixedArray[Byte] = FixedArray::make(16, 0)
  for i in 0..<n {
    buf[i] = bytes[i]
  }
  let v = @v128.v128_load(buf, 0)
  let valid_bits = (1 << n) - 1
  let dots = @v128.i8x16_bitmask(@v128.i8x16_eq(v, @v128.i8x16_splat(b'.'))) &
    valid_bits
  let digits = @v128.i8x16_bitmask(
      @v128.v128_and_(
        @v128.i8x16_ge_u(v, @v128.i8x16_splat(b'0')),
        @v128.i8x16_le_u(v, @v128.i8x16_splat(b'9')),
      ),
    ) &
    valid_bits
  // every position must be a digit or a dot, and there must be exactly 3 dots
  if (digits | dots) != valid_bits || dots.popcnt() != 3 {
    return None
  }
  let d1 = dots.ctz()
  let m2 = dots & (dots - 1)
  let d2 = m2.ctz()
  let d3 = (m2 & (m2 - 1)).ctz()
  let a = octet(bytes, 0, d1)
  let b = octet(bytes, d1 + 1, d2)
  let c = octet(bytes, d2 + 1, d3)
  let d = octet(bytes, d3 + 1, n)
  if (a | b | c | d) < 0 {
    return None
  }
  Some(
    (a.reinterpret_as_uint() << 24) |
    (b.reinterpret_as_uint() << 16) |
    (c.reinterpret_as_uint() << 8) |
    d.reinterpret_as_uint(),
  )
}

///|
fn put_octet(buf : FixedArray[Byte], pos : Int, value : UInt) -> Int {
  if value >= 100U {
    buf[pos] = b'0' + (value / 100U).to_byte()
    buf[pos + 1] = b'0' + (value / 10U % 10U).to_byte()
    buf[pos + 2] = b'0' + (value % 10U).to_byte()
    pos + 3
  } else if value >= 10U {
    buf[pos] = b'0' + (value / 10U).to_byte()
    buf[pos + 1] = b'0' + (value % 10U).to_byte()
    pos + 2
  } else {
    buf[pos] = b'0' + value.to_byte()
    pos + 1
  }
}

///|
/// Formats a big-endian `UInt` IPv4 address as a dotted-quad string.
pub fn format(addr : UInt) -> FixedArray[Byte] {
  let buf : FixedArray[Byte] = FixedArray::make(15, 0)
  let mut p = put_octet(buf, 0, (addr >> 24) & 0xffU)
  buf[p] = b'.'
  p = put_octet(buf, p + 1, (addr >> 16) & 0xffU)
  buf[p] = b'.'
  p = put_octet(buf, p + 1, (addr >> 8) & 0xffU)
  buf[p] = b'.'
  p = put_octet(buf, p + 1, addr & 0xffU)
  if p == 15 {
    return buf
  }
  let out : FixedArray[Byte] = FixedArray::make(p, 0)
  for k in 0..<p {
    out[k] = buf[k]
  }
  out
}
