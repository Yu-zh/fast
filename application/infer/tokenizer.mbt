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

// The llama2.c SentencePiece-style BPE tokenizer. `tokenizer.bin` is an int32
// max-token-length followed, per vocab entry, by a float32 score, an int32
// byte length, and that many raw bytes. `encode` adds an optional BOS, a
// dummy-prefix space, maps each UTF-8 character to a vocab id (falling back to
// raw byte tokens at id `byte+3`), then greedily merges the highest-scoring
// adjacent pair until none remain. `decode` reverses a token to its bytes,
// expanding `<0xXX>` byte tokens and stripping the dummy prefix after BOS.

///|
pub(all) struct Tokenizer {
  vocab : Array[Bytes]
  scores : Array[Float]
  lookup : Map[Bytes, Int]
}

///|
fn slice_bytes(d : Bytes, start : Int, len : Int) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<len {
    out.push(d[start + i])
  }
  Bytes::from_array(out)
}

///|
fn concat_bytes(a : Bytes, b : Bytes) -> Bytes {
  let out : Array[Byte] = []
  for i in 0..<a.length() {
    out.push(a[i])
  }
  for i in 0..<b.length() {
    out.push(b[i])
  }
  Bytes::from_array(out)
}

///|
/// Parses a `tokenizer.bin` for a vocabulary of `vocab_size` entries.
pub fn Tokenizer::from_bytes(data : Bytes, vocab_size : Int) -> Tokenizer {
  let vocab : Array[Bytes] = []
  let scores : Array[Float] = []
  let lookup : Map[Bytes, Int] = Map([])
  let mut off = 4 // skip max_token_length
  for id in 0..<vocab_size {
    let score = f32le(data, off)
    off = off + 4
    let len = i32le(data, off)
    off = off + 4
    let tok = slice_bytes(data, off, len)
    off = off + len
    vocab.push(tok)
    scores.push(score)
    lookup[tok] = id
  }
  Tokenizer::{ vocab, scores, lookup }
}

///|
/// UTF-8 encodes a string to a byte array.
fn utf8_encode(text : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for c in text.iter() {
    let cp = c.to_int()
    if cp < 0x80 {
      out.push(cp.to_byte())
    } else if cp < 0x800 {
      out.push((0xC0 | (cp >> 6)).to_byte())
      out.push((0x80 | (cp & 0x3F)).to_byte())
    } else if cp < 0x10000 {
      out.push((0xE0 | (cp >> 12)).to_byte())
      out.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      out.push((0x80 | (cp & 0x3F)).to_byte())
    } else {
      out.push((0xF0 | (cp >> 18)).to_byte())
      out.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
      out.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      out.push((0x80 | (cp & 0x3F)).to_byte())
    }
  }
  out
}

///|
/// Encodes `text` into token ids, optionally bracketed by BOS (1) / EOS (2).
pub fn Tokenizer::encode(
  self : Tokenizer,
  text : String,
  bos : Bool,
  eos : Bool,
) -> Array[Int] {
  let tokens : Array[Int] = []
  if bos {
    tokens.push(1)
  }
  // SentencePiece dummy prefix: a leading space, when the text is non-empty
  if text.length() > 0 {
    match self.lookup.get(Bytes::from_array([b' '])) {
      Some(id) => tokens.push(id)
      None => ()
    }
  }
  let bytes = utf8_encode(text)
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let lead = bytes[i].to_int()
    let clen = if lead < 0x80 {
      1
    } else if lead < 0xE0 {
      2
    } else if lead < 0xF0 {
      3
    } else {
      4
    }
    let clen = if i + clen > n { n - i } else { clen }
    let cbytes = slice_bytes(Bytes::from_array(bytes), i, clen)
    match self.lookup.get(cbytes) {
      Some(id) => tokens.push(id)
      None =>
        // byte fallback: raw bytes are tokens at id (byte + 3)
        for j in 0..<clen {
          tokens.push(bytes[i + j].to_int() + 3)
        }
    }
    i = i + clen
  }
  // greedily merge the best adjacent pair until none can be merged
  while true {
    let mut best_score = (-1.0e30 : Float)
    let mut best_id = -1
    let mut best_idx = -1
    for idx in 0..<(tokens.length() - 1) {
      let merged = concat_bytes(
        self.vocab[tokens[idx]],
        self.vocab[tokens[idx + 1]],
      )
      match self.lookup.get(merged) {
        Some(id) =>
          if self.scores[id] > best_score {
            best_score = self.scores[id]
            best_id = id
            best_idx = idx
          }
        None => ()
      }
    }
    if best_idx == -1 {
      break
    }
    tokens[best_idx] = best_id
    tokens.remove(best_idx + 1) |> ignore
  }
  if eos {
    tokens.push(2)
  }
  tokens
}

///|
fn hex_value(b : Byte) -> Int {
  let v = b.to_int()
  if v >= 0x30 && v <= 0x39 {
    v - 0x30
  } else if v >= 0x41 && v <= 0x46 {
    v - 0x41 + 10
  } else if v >= 0x61 && v <= 0x66 {
    v - 0x61 + 10
  } else {
    -1
  }
}

///|
/// Decodes one `token` (following `prev`) back to its raw bytes, expanding
/// `<0xXX>` byte tokens and dropping the dummy-prefix space after BOS.
pub fn Tokenizer::decode(self : Tokenizer, prev : Int, token : Int) -> Bytes {
  let piece = self.vocab[token]
  // a "<0xXX>" byte token decodes to that single raw byte
  if piece.length() == 6 &&
    piece[0] == b'<' &&
    piece[1] == b'0' &&
    piece[2] == b'x' &&
    piece[5] == b'>' {
    let hi = hex_value(piece[3])
    let lo = hex_value(piece[4])
    if hi >= 0 && lo >= 0 {
      return Bytes::from_array([((hi << 4) | lo).to_byte()])
    }
  }
  // after BOS, a leading space from the dummy prefix is dropped
  if prev == 1 && piece.length() > 0 && piece[0] == b' ' {
    return slice_bytes(piece, 1, piece.length() - 1)
  }
  piece
}
