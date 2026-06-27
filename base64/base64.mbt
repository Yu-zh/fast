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

// Vectorized standard base64 (RFC 4648) over `FixedArray[Byte]`, following
// the SIMD approach of Muła & Lemire ("Faster Base64 Encoding and Decoding
// using AVX2"). Encoding processes 12 input bytes per step into 16 output
// characters; its 6-bit field split avoids `mulhi`/`mullo` (which v128 does
// not expose) by using per-16-bit-lane shifts blended with `v128_bitselect`.
// Decoding processes 16 characters into 12 bytes, classifying ASCII -> sextet
// with a perfect hash on the high nibble and packing with `dot`-based madd.

///|
let alphabet : Bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

// --- encode ---------------------------------------------------------------

///|
/// Reshuffle that lays each 3-byte group out as `[n1, n0, n2, n1]` within a
/// 32-bit lane, so the low 16 bits carry `(n0, n1)` for output chars 0-1 and
/// the high 16 bits carry `(n1, n2)` for output chars 2-3.
let enc_shuffle : V128 = @v128.i8x16_const(
  1, 0, 2, 1, 4, 3, 5, 4, 7, 6, 8, 7, 10, 9, 11, 10,
)

///|
/// Picks the low 16 bits of every 32-bit lane: `0xffff` on even 16-bit lanes.
let even16 : V128 = @v128.i32x4_splat(0x0000ffff)

///|
/// Offset added to each 6-bit index to produce its ASCII character, indexed by
/// the bucket id computed in `encode`. The five alphabet ranges need different
/// offsets (mod 256): bucket 0 -> a-z (+71); 1-10 -> 0-9 (-4 = 252); 11 -> '+'
/// (-19 = 237); 12 -> '/' (-16 = 240); 13 -> A-Z (+65).
let enc_offsets : V128 = @v128.i8x16_const(
  71, 252, 252, 252, 252, 252, 252, 252, 252, 252, 252, 237, 240, 65, 0, 0,
)

///|
/// Encodes `bytes` as standard, padded base64.
pub fn encode(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let len = bytes.length()
  let out_len = (len + 2) / 3 * 4
  let out : FixedArray[Byte] = FixedArray::make(out_len, 0)
  let mut i = 0
  let mut o = 0
  // SIMD: needs a full 16-byte load even though only 12 bytes are consumed.
  while i + 16 <= len {
    let v = @v128.v128_load(bytes, i)
    let shuffled = @v128.i8x16_swizzle(v, enc_shuffle)
    // Extract the four 6-bit sextets c0..c3 of each group into bytes 0..3 of
    // its lane. c0 and c2 sit at the top of their byte: mask them with
    // 0x0fc0fc00, then right-shift — c0 (even/low 16-bit lane) by 10, c2
    // (odd/high lane) by 6 — and blend the two shifts by lane parity.
    let hi = @v128.v128_and_(shuffled, @v128.i32x4_splat(0x0fc0fc00))
    let field0 = @v128.v128_bitselect(
      @v128.i16x8_shr_u(hi, 10),
      @v128.i16x8_shr_u(hi, 6),
      even16,
    )
    // c1 and c3 sit at the bottom: mask with 0x003f03f0 and left-shift — c1
    // (even lane) by 4, c3 (odd lane) by 8 — again blended by lane parity.
    let lo = @v128.v128_and_(shuffled, @v128.i32x4_splat(0x003f03f0))
    let field1 = @v128.v128_bitselect(
      @v128.i16x8_shl(lo, 4),
      @v128.i16x8_shl(lo, 8),
      even16,
    )
    let indices = @v128.v128_or_(field0, field1)
    // Bucket each sextet into 0..13 to look up its ASCII offset: a saturating
    // `- 51` maps 0-9/+// (values >= 52) to 1-12, and the `< 26` test adds 13
    // to flag the A-Z range; everything else stays bucket 0 (a-z).
    let bucket = @v128.v128_or_(
      @v128.i8x16_sub_sat_u(indices, @v128.i8x16_splat(51)),
      @v128.v128_and_(
        @v128.i8x16_lt_u(indices, @v128.i8x16_splat(26)),
        @v128.i8x16_splat(13),
      ),
    )
    let chars = @v128.i8x16_add(
      indices,
      @v128.i8x16_swizzle(enc_offsets, bucket),
    )
    @v128.v128_store(out, o, chars)
    i = i + 12
    o = o + 16
  }
  // scalar tail
  while i + 3 <= len {
    let n0 = bytes[i].to_int()
    let n1 = bytes[i + 1].to_int()
    let n2 = bytes[i + 2].to_int()
    out[o] = alphabet[n0 >> 2]
    out[o + 1] = alphabet[((n0 & 0x03) << 4) | (n1 >> 4)]
    out[o + 2] = alphabet[((n1 & 0x0f) << 2) | (n2 >> 6)]
    out[o + 3] = alphabet[n2 & 0x3f]
    i = i + 3
    o = o + 4
  }
  let rem = len - i
  if rem == 1 {
    let n0 = bytes[i].to_int()
    out[o] = alphabet[n0 >> 2]
    out[o + 1] = alphabet[(n0 & 0x03) << 4]
    out[o + 2] = b'='
    out[o + 3] = b'='
  } else if rem == 2 {
    let n0 = bytes[i].to_int()
    let n1 = bytes[i + 1].to_int()
    out[o] = alphabet[n0 >> 2]
    out[o + 1] = alphabet[((n0 & 0x03) << 4) | (n1 >> 4)]
    out[o + 2] = alphabet[(n1 & 0x0f) << 2]
    out[o + 3] = b'='
  }
  out
}

// --- decode ---------------------------------------------------------------

///|
/// Gathers the three output bytes of each 32-bit lane (big-endian order)
/// down to the low 12 bytes of the vector.
let dec_gather : V128 = @v128.i8x16_const(
  2, 1, 0, 6, 5, 4, 10, 9, 8, 14, 13, 12, 0xff, 0xff, 0xff, 0xff,
)

///|
/// Combine weights for the two `dot`/`madd` steps that pack 4 six-bit values
/// into a 24-bit big-endian integer per lane.
let dec_madd : V128 = @v128.i16x8_const(
  0x1000, 0x0001, 0x1000, 0x0001, 0x1000, 0x0001, 0x1000, 0x0001,
)

///|
fn decode_value(b : Byte) -> Int {
  if b >= b'A' && b <= b'Z' {
    (b - b'A').to_int()
  } else if b >= b'a' && b <= b'z' {
    (b - b'a').to_int() + 26
  } else if b >= b'0' && b <= b'9' {
    (b - b'0').to_int() + 52
  } else if b == b'+' {
    62
  } else if b == b'/' {
    63
  } else {
    -1
  }
}

// The decode classifier uses the perfect hash `(byte >> 4) - (byte == '/')`
// (Muła; popularized by mcyoung, "Designing a SIMD Algorithm from Scratch").
// It maps the five alphabet ranges to distinct buckets:
//   /  -> 1     +  -> 2     0-9 -> 3     A-O -> 4   P-Z -> 5
//   a-o -> 6    p-z -> 7
// indexing three swizzle tables: the sextet offset to add, plus the inclusive
// `[lo, hi]` ASCII range valid for each bucket (used for validation, which the
// hash no longer provides for free). Buckets 0 and 8-15 use an empty range.

///|
/// Offset added to each ASCII byte to yield its 6-bit value, per hash bucket.
let dec_offset : V128 = @v128.i8x16_const(
  0, 16, 19, 4, 0xbf, 0xbf, 0xb9, 0xb9, 0, 0, 0, 0, 0, 0, 0, 0,
)

///|
/// Inclusive lower bound of the ASCII range valid for each hash bucket.
let dec_lo : V128 = @v128.i8x16_const(
  0xff, b'/', b'+', b'0', b'A', b'P', b'a', b'p', 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
  0xff, 0xff,
)

///|
/// Inclusive upper bound of the ASCII range valid for each hash bucket.
let dec_hi : V128 = @v128.i8x16_const(
  0, b'/', b'+', b'9', b'O', b'Z', b'o', b'z', 0, 0, 0, 0, 0, 0, 0, 0,
)

///|
/// High nibble of every byte (`(b >> 4) & 0x0f`), via a 16-bit lane shift.
fn high_nibbles(v : V128) -> V128 {
  @v128.v128_and_(@v128.i16x8_shr_u(v, 4), @v128.i8x16_splat(0x0f))
}

///|
/// Maps a 16-character block to its 16 six-bit values, or `None` if any
/// character is not in the base64 alphabet.
fn decode_block(v : V128) -> V128? {
  // hash bucket: high nibble, minus one for '/' (adding 0xff wraps to -1)
  let hash = @v128.i8x16_add(
    high_nibbles(v),
    @v128.i8x16_eq(v, @v128.i8x16_splat(b'/')),
  )
  // validate: each byte must fall in its bucket's [lo, hi] range
  let valid = @v128.v128_and_(
    @v128.i8x16_ge_u(v, @v128.i8x16_swizzle(dec_lo, hash)),
    @v128.i8x16_le_u(v, @v128.i8x16_swizzle(dec_hi, hash)),
  )
  if @v128.i8x16_bitmask(valid) != 0xffff {
    return None
  }
  Some(@v128.i8x16_add(v, @v128.i8x16_swizzle(dec_offset, hash)))
}

///|
/// Packs 16 six-bit values (4 per 32-bit lane) into 12 output bytes held in
/// the low 12 bytes of the result.
fn decode_pack(values : V128) -> V128 {
  // maddubs with weights [64, 1]: each 16-bit lane becomes v_even*64 + v_odd.
  let merged = @v128.i16x8_add(
    @v128.i16x8_shl(@v128.v128_and_(values, @v128.i16x8_splat(0x00ff)), 6),
    @v128.i16x8_shr_u(values, 8),
  )
  // madd with [0x1000, 1]: each 32-bit lane becomes the 24-bit big-endian
  // value `v0<<18 | v1<<12 | v2<<6 | v3`.
  let packed = @v128.i32x4_dot_i16x8_s(merged, dec_madd)
  @v128.i8x16_swizzle(packed, dec_gather)
}

///|
/// Decodes standard base64. Accepts input with or without `=` padding;
/// returns `None` for any character outside the alphabet, misplaced padding,
/// or a length that cannot be valid base64.
pub fn decode(input : FixedArray[Byte]) -> FixedArray[Byte]? {
  let len = input.length()
  let mut pad = 0
  if len >= 1 && input[len - 1] == b'=' {
    pad = 1
    if len >= 2 && input[len - 2] == b'=' {
      pad = 2
    }
  }
  let sig = len - pad
  let rem = sig % 4
  if rem == 1 {
    return None
  }
  let out_len = sig / 4 * 3 + (if rem == 0 { 0 } else { rem - 1 })
  let out : FixedArray[Byte] = FixedArray::make(out_len, 0)
  let mut i = 0
  let mut o = 0
  while i + 16 <= sig {
    guard decode_block(@v128.v128_load(input, i)) is Some(values) else {
      return None
    }
    let packed = decode_pack(values)
    @v128.v128_store64_lane(out, o, packed, 0)
    @v128.v128_store32_lane(out, o + 8, packed, 2)
    i = i + 16
    o = o + 12
  }
  // scalar tail: full 4-char groups, then a final 2- or 3-char group
  while i + 4 <= sig {
    let a = decode_value(input[i])
    let b = decode_value(input[i + 1])
    let c = decode_value(input[i + 2])
    let d = decode_value(input[i + 3])
    if (a | b | c | d) < 0 {
      return None
    }
    out[o] = ((a << 2) | (b >> 4)).to_byte()
    out[o + 1] = (((b & 0x0f) << 4) | (c >> 2)).to_byte()
    out[o + 2] = (((c & 0x03) << 6) | d).to_byte()
    i = i + 4
    o = o + 3
  }
  if sig - i == 2 {
    let a = decode_value(input[i])
    let b = decode_value(input[i + 1])
    if (a | b) < 0 {
      return None
    }
    out[o] = ((a << 2) | (b >> 4)).to_byte()
  } else if sig - i == 3 {
    let a = decode_value(input[i])
    let b = decode_value(input[i + 1])
    let c = decode_value(input[i + 2])
    if (a | b | c) < 0 {
      return None
    }
    out[o] = ((a << 2) | (b >> 4)).to_byte()
    out[o + 1] = (((b & 0x0f) << 4) | (c >> 2)).to_byte()
  }
  Some(out)
}
