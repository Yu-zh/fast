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

// IPv4 CIDR parsing and allowlist matching. Addresses are parsed with
// `Yu-zh/fast`'s SIMD `ipv4.parse` (the whole dotted-quad classified in one
// vector); a prefix length collapses to a 32-bit mask, so membership is a
// single masked compare. An `Allowlist` is just a vector of prefixes scanned
// for the first match.

///|
fn slice(d : FixedArray[Byte], start : Int, end : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(end - start, 0)
  for i in 0..<(end - start) {
    out[i] = d[start + i]
  }
  out
}

///|
/// The /prefix network mask (e.g. /24 -> 0xFFFFFF00).
fn mask_of(prefix : Int) -> UInt {
  if prefix <= 0 {
    0
  } else if prefix >= 32 {
    0xFFFFFFFF
  } else {
    0xFFFFFFFF << (32 - prefix)
  }
}

///|
/// An IPv4 network: a base address (masked) and a prefix length.
pub struct Cidr {
  base : UInt
  prefix : Int
}

///|
/// Parses `"a.b.c.d/n"` (or a bare `"a.b.c.d"`, treated as `/32`). Returns
/// `None` on a malformed address or an out-of-range prefix.
pub fn parse(s : FixedArray[Byte]) -> Cidr? {
  let n = s.length()
  let mut slash = -1
  for i in 0..<n {
    if s[i] == b'/' {
      slash = i
      break
    }
  }
  let ip_end = if slash < 0 { n } else { slash }
  let prefix = if slash < 0 {
    32
  } else {
    let mut p = 0
    let mut any = false
    for i in (slash + 1)..<n {
      let c = s[i]
      if c < b'0' || c > b'9' {
        return None
      }
      p = p * 10 + (c - b'0').to_int()
      any = true
      if p > 32 {
        return None
      }
    }
    if !any {
      return None
    }
    p
  }
  match @ipv4.parse(slice(s, 0, ip_end)) {
    Some(ip) => Some(Cidr::{ base: ip & mask_of(prefix), prefix })
    None => None
  }
}

///|
/// Whether `ip` (a packed big-endian address, as from `ipv4.parse`) is in the
/// network.
pub fn Cidr::contains(self : Cidr, ip : UInt) -> Bool {
  (ip & mask_of(self.prefix)) == self.base
}

///|
/// Whether a dotted-quad address string is in the network.
pub fn Cidr::contains_bytes(self : Cidr, ip : FixedArray[Byte]) -> Bool {
  match @ipv4.parse(ip) {
    Some(v) => self.contains(v)
    None => false
  }
}

///|
/// A set of CIDR networks.
pub struct Allowlist {
  entries : Array[Cidr]
}

///|
/// Builds an allowlist from CIDR strings; `None` if any entry is malformed.
pub fn Allowlist::of(cidrs : Array[FixedArray[Byte]]) -> Allowlist? {
  let entries : Array[Cidr] = []
  for c in cidrs {
    match parse(c) {
      Some(x) => entries.push(x)
      None => return None
    }
  }
  Some(Allowlist::{ entries, })
}

///|
/// Whether any network in the list contains `ip`.
pub fn Allowlist::allows(self : Allowlist, ip : UInt) -> Bool {
  for e in self.entries {
    if e.contains(ip) {
      return true
    }
  }
  false
}

///|
/// Whether any network contains the dotted-quad address string.
pub fn Allowlist::allows_bytes(self : Allowlist, ip : FixedArray[Byte]) -> Bool {
  match @ipv4.parse(ip) {
    Some(v) => self.allows(v)
    None => false
  }
}
