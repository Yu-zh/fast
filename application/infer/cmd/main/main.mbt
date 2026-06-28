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

// CLI entry point: loads a llama2.c checkpoint + tokenizer, encodes a prompt,
// and streams generated text. Run (native is much faster — v128 lowers to real
// SIMD there):
//
//   moon run application/infer/cmd/main --target native -- \
//       stories15M.bin tokenizer.bin "Once upon a time" 256
//
// Get the model: stories15M.bin from karpathy/tinyllamas and tokenizer.bin
// from the llama2.c repo.

///|
fn parse_int(s : String, default : Int) -> Int {
  let mut v = 0
  let mut any = false
  for c in s.iter() {
    let d = c.to_int() - 0x30
    if d < 0 || d > 9 {
      return default
    }
    v = v * 10 + d
    any = true
  }
  if any {
    v
  } else {
    default
  }
}

///|
/// Decodes UTF-8 bytes to a string for printing.
fn utf8_decode(bytes : Array[Byte]) -> String {
  let sb = StringBuilder::new()
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let b = bytes[i].to_int()
    if b < 0x80 {
      sb.write_char(b.unsafe_to_char())
      i = i + 1
    } else if b < 0xE0 && i + 1 < n {
      let cp = ((b & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      sb.write_char(cp.unsafe_to_char())
      i = i + 2
    } else if b < 0xF0 && i + 2 < n {
      let cp = ((b & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      sb.write_char(cp.unsafe_to_char())
      i = i + 3
    } else if i + 3 < n {
      let cp = ((b & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      sb.write_char(cp.unsafe_to_char())
      i = i + 4
    } else {
      i = i + 1
    }
  }
  sb.to_string()
}

///|
fn main {
  let args = @env.args()
  // accept args with or without a leading program-name entry
  let start = if args.length() >= 1 &&
    (args[0].has_suffix(".bin") || args.length() <= 2) {
    0
  } else if args.length() >= 1 {
    1
  } else {
    0
  }
  let argc = args.length() - start
  if argc < 2 {
    println(
      "usage: <checkpoint.bin> <tokenizer.bin> [prompt] [steps] [temperature x100] [seed]",
    )
    return
  }
  let checkpoint = args[start]
  let tokenizer_path = args[start + 1]
  let prompt = if argc >= 3 { args[start + 2] } else { "" }
  let steps = if argc >= 4 { parse_int(args[start + 3], 256) } else { 256 }
  // temperature given as an integer percent (e.g. 100 = 1.0) to avoid float args
  let temperature = if argc >= 5 {
    Float::from_int(parse_int(args[start + 4], 100)) / (100.0 : Float)
  } else {
    (1.0 : Float)
  }
  let seed = if argc >= 6 { parse_int(args[start + 5], 42) } else { 42 }
  let cp_bytes = @fs.read_file_to_bytes(checkpoint) catch {
    _ => {
      println("error: could not read checkpoint file: " + checkpoint)
      return
    }
  }
  let tok_bytes = @fs.read_file_to_bytes(tokenizer_path) catch {
    _ => {
      println("error: could not read tokenizer file: " + tokenizer_path)
      return
    }
  }
  let (config, weights) = @infer.load_checkpoint(cp_bytes)
  let tokenizer = @infer.Tokenizer::from_bytes(tok_bytes, config.vocab_size)
  // quantize weights to int8 on load (~4x less memory traffic in the matmuls)
  let model = @infer.QTransformer::new(config, weights)
  let prompt_tokens = tokenizer.encode(prompt, true, false)
  if prompt_tokens.length() == 0 {
    println("(empty prompt produced no tokens)")
    return
  }
  let rng = @infer.Rng::new(seed.reinterpret_as_uint())
  let max_steps = if steps < config.seq_len { steps } else { config.seq_len }
  let topp = (0.9 : Float)
  let out : Array[Byte] = []
  let mut token = prompt_tokens[0]
  let mut pos = 0
  while pos < max_steps {
    let logits = model.forward(token, pos)
    let next = if pos + 1 < prompt_tokens.length() {
      prompt_tokens[pos + 1]
    } else {
      @infer.sample(logits, temperature, topp, rng)
    }
    pos = pos + 1
    if next == 1 {
      break // BOS delimits; stop generation
    }
    let piece = tokenizer.decode(token, next)
    for i in 0..<piece.length() {
      out.push(piece[i])
    }
    token = next
  }
  println(utf8_decode(out))
}
