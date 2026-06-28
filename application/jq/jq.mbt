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

// A small NDJSON (JSON-lines) query tool, built on `Yu-zh/fast`. Lines are
// split with SIMD `memchr`; a substring filter uses SIMD `memmem`; `minify`
// reuses the SIMD JSON minifier. `field` pulls a top-level value out of a flat
// JSON object (the common shape for log lines) by locating `"key":` with
// `memmem` and scanning the value token.

///|
fn slice(d : FixedArray[Byte], start : Int, end : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(end - start, 0)
  for i in 0..<(end - start) {
    out[i] = d[start + i]
  }
  out
}

///|
/// The byte ranges `[start, end)` of each line in `data` (newline excluded).
pub fn lines(data : FixedArray[Byte]) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let n = data.length()
  let mut start = 0
  while start < n {
    let e = match @memchr.find_byte(data, b'\n', from=start) {
      Some(i) => i
      None => n
    }
    out.push((start, e))
    start = e + 1
  }
  out
}

///|
/// The lines of `data` that contain `needle`, as byte slices.
pub fn select_contains(
  data : FixedArray[Byte],
  needle : FixedArray[Byte],
) -> Array[FixedArray[Byte]] {
  let out : Array[FixedArray[Byte]] = []
  for ln in lines(data) {
    let line = slice(data, ln.0, ln.1)
    if @memmem.contains(line, needle) {
      out.push(line)
    }
  }
  out
}

///|
/// Extracts the raw value of top-level `"key"` from a flat JSON object. For a
/// string value the surrounding quotes are stripped; for numbers/`true`/`false`/
/// `null` the literal token is returned. `None` if the key is absent.
pub fn field(
  obj : FixedArray[Byte],
  key : FixedArray[Byte],
) -> FixedArray[Byte]? {
  let needle : FixedArray[Byte] = FixedArray::make(key.length() + 3, 0)
  needle[0] = b'"'
  for i in 0..<key.length() {
    needle[i + 1] = key[i]
  }
  needle[key.length() + 1] = b'"'
  needle[key.length() + 2] = b':'
  match @memmem.find(obj, needle) {
    None => None
    Some(p) => {
      let n = obj.length()
      let mut v = p + needle.length()
      while v < n && (obj[v] == b' ' || obj[v] == b'\t') {
        v = v + 1
      }
      if v >= n {
        return None
      }
      if obj[v] == b'"' {
        let mut e = v + 1
        while e < n && obj[e] != b'"' {
          e = if obj[e] == b'\\' { e + 2 } else { e + 1 }
        }
        Some(slice(obj, v + 1, if e < n { e } else { n }))
      } else {
        let mut e = v
        while e < n {
          let c = obj[e]
          if c == b',' ||
            c == b'}' ||
            c == b']' ||
            c == b' ' ||
            c == b'\t' ||
            c == b'\n' ||
            c == b'\r' {
            break
          }
          e = e + 1
        }
        Some(slice(obj, v, e))
      }
    }
  }
}

///|
/// Minifies a JSON document (strips insignificant whitespace) via the SIMD
/// JSON minifier; `None` if the input is not well-formed JSON.
pub fn minify(obj : FixedArray[Byte]) -> FixedArray[Byte]? {
  @json.minify(obj)
}
