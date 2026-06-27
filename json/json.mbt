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

// simdjson-style "stage 1" structural scanning (Langdale & Lemire,
// "Parsing Gigabytes of JSON per Second"). SIMD classification produces
// 64-bit masks (four 16-byte blocks per stride); string interiors and
// escapes are then resolved with branchless 64-bit arithmetic: a
// carry-propagating trick finds escaped characters, and a prefix-XOR turns
// quote bits into in-string regions.

///|
/// Per-16-byte-block classification masks, packed into one word to avoid
/// allocating a tuple per block: op | ws<<16 | quote<<32 | backslash<<48.
fn block_masks(v : V128) -> UInt64 {
  let ws = @v128.v128_or_(
    @v128.v128_or_(
      @v128.i8x16_eq(v, @v128.i8x16_splat(b' ')),
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'\t')),
    ),
    @v128.v128_or_(
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'\n')),
      @v128.i8x16_eq(v, @v128.i8x16_splat(b'\r')),
    ),
  )
  // `|0x20` folds '[' onto '{' and ']' onto '}', so two compares cover the
  // four brackets
  let curl = @v128.v128_or_(v, @v128.i8x16_splat(0x20))
  let op = @v128.v128_or_(
    @v128.v128_or_(
      @v128.i8x16_eq(curl, @v128.i8x16_splat(b'{')),
      @v128.i8x16_eq(curl, @v128.i8x16_splat(b'}')),
    ),
    @v128.v128_or_(
      @v128.i8x16_eq(v, @v128.i8x16_splat(b':')),
      @v128.i8x16_eq(v, @v128.i8x16_splat(b',')),
    ),
  )
  let quote = @v128.i8x16_eq(v, @v128.i8x16_splat(b'"'))
  let backslash = @v128.i8x16_eq(v, @v128.i8x16_splat(b'\\'))
  @v128.i8x16_bitmask(op).to_uint64() |
  (@v128.i8x16_bitmask(ws).to_uint64() << 16) |
  (@v128.i8x16_bitmask(quote).to_uint64() << 32) |
  (@v128.i8x16_bitmask(backslash).to_uint64() << 48)
}

///|
/// XOR-prefix-sum over bits: bit i of the result is the parity of bits
/// 0..=i of the input (a carry-less multiply by all-ones).
fn prefix_xor(mask : UInt64) -> UInt64 {
  let mut x = mask
  x = x ^ (x << 1)
  x = x ^ (x << 2)
  x = x ^ (x << 4)
  x = x ^ (x << 8)
  x = x ^ (x << 16)
  x = x ^ (x << 32)
  x
}

///|
/// Returns the positions where a parser needs to look: every structural
/// character (`{`, `}`, `[`, `]`, `:`, `,`), the opening quote of every
/// string, and the first byte of every other scalar (number, `true`,
/// `false`, `null`) — all outside string contents. Returns `None` when a
/// string is left unclosed at the end of input.
pub fn structural_indices(bytes : FixedArray[Byte]) -> Array[Int]? {
  let len = bytes.length()
  // realistic documents average one mark per 6-8 bytes
  let out : Array[Int] = Array::new(capacity=len / 6 + 4)
  let mut prev_in_string = 0UL // all ones when a string spans the boundary
  let mut prev_escaped = 0UL
  let mut prev_scalar = 0UL
  let mut base = 0
  while base < len || base == 0 {
    // classification masks for this 64-byte stride
    let mut packed0 = 0UL
    let mut packed1 = 0UL
    let mut packed2 = 0UL
    let mut packed3 = 0UL
    if len - base >= 64 {
      packed0 = block_masks(@v128.v128_load(bytes, base))
      packed1 = block_masks(@v128.v128_load(bytes, base + 16))
      packed2 = block_masks(@v128.v128_load(bytes, base + 32))
      packed3 = block_masks(@v128.v128_load(bytes, base + 48))
    } else {
      // pad the final stride with whitespace, which generates no marks
      let tail : FixedArray[Byte] = FixedArray::make(64, b' ')
      for j in 0..<(len - base) {
        tail[j] = bytes[base + j]
      }
      packed0 = block_masks(@v128.v128_load(tail, 0))
      packed1 = block_masks(@v128.v128_load(tail, 16))
      packed2 = block_masks(@v128.v128_load(tail, 32))
      packed3 = block_masks(@v128.v128_load(tail, 48))
    }
    let lane = 0xffffUL
    let op = (packed0 & lane) |
      ((packed1 & lane) << 16) |
      ((packed2 & lane) << 32) |
      ((packed3 & lane) << 48)
    let ws = ((packed0 >> 16) & lane) |
      (((packed1 >> 16) & lane) << 16) |
      (((packed2 >> 16) & lane) << 32) |
      (((packed3 >> 16) & lane) << 48)
    let quote_raw = ((packed0 >> 32) & lane) |
      (((packed1 >> 32) & lane) << 16) |
      (((packed2 >> 32) & lane) << 32) |
      (((packed3 >> 32) & lane) << 48)
    let backslash_raw = ((packed0 >> 48) & lane) |
      (((packed1 >> 48) & lane) << 16) |
      (((packed2 >> 48) & lane) << 32) |
      (((packed3 >> 48) & lane) << 48)
    // characters escaped by an odd-length backslash run, with the run
    // carried across stride boundaries (prev_escaped is 0 or 1)
    let backslash = backslash_raw & prev_escaped.lnot()
    let follows_escape = (backslash << 1) | prev_escaped
    let even_bits = 0x5555555555555555UL
    let odd_sequence_starts = backslash &
      even_bits.lnot() &
      follows_escape.lnot()
    let sum = odd_sequence_starts + backslash
    prev_escaped = if sum < odd_sequence_starts { 1UL } else { 0UL }
    let escaped = (even_bits ^ (sum << 1)) & follows_escape
    let quote = quote_raw & escaped.lnot()
    // in-string covers the opening quote up to (excluding) the closing one
    let in_string = prefix_xor(quote) ^ prev_in_string
    prev_in_string = (in_string.reinterpret_as_int64() >> 63).reinterpret_as_uint64()
    let scalar = (op | ws).lnot()
    let nonquote_scalar = scalar & quote.lnot()
    let follows_nonquote_scalar = (nonquote_scalar << 1) | prev_scalar
    prev_scalar = nonquote_scalar >> 63
    // string interior plus the closing quote; the opening quote stays a
    // structural mark
    let string_tail = in_string ^ quote
    let mut structural = (op | (scalar & follows_nonquote_scalar.lnot())) &
      string_tail.lnot()
    while structural != 0UL {
      out.push(base + structural.ctz())
      structural = structural & (structural - 1)
    }
    base = base + 64
  }
  if prev_in_string != 0UL {
    return None
  }
  Some(out)
}
