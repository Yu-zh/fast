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

// A tiny CSV analytics engine, built on `Yu-zh/fast`. Records are split with
// the SIMD CSV field scanner (`csv.split_records`, which vectorizes the comma /
// quote / newline classification) into `(start, end)` field ranges; numeric
// aggregations parse cells with SIMD-friendly `atoi`. Non-numeric cells (a
// header row, blanks) are skipped, so aggregates work without pre-stripping a
// header.

///|
fn slice(d : FixedArray[Byte], start : Int, end : Int) -> FixedArray[Byte] {
  let out : FixedArray[Byte] = FixedArray::make(end - start, 0)
  for i in 0..<(end - start) {
    out[i] = d[start + i]
  }
  out
}

///|
/// A parsed CSV table: the backing bytes plus per-row field ranges.
pub struct Table {
  data : FixedArray[Byte]
  rows : Array[Array[(Int, Int)]]
}

///|
/// Parses comma-separated `data` into a `Table`; `None` if the CSV is malformed
/// (e.g. an unterminated quote).
pub fn parse(data : FixedArray[Byte]) -> Table? {
  match @csv.split_records(data) {
    Some(rows) => Some(Table::{ data, rows })
    None => None
  }
}

///|
/// The number of records (rows).
pub fn Table::row_count(self : Table) -> Int {
  self.rows.length()
}

///|
/// The raw bytes of the cell at `(row, col)`, empty if out of range.
pub fn Table::cell(self : Table, row : Int, col : Int) -> FixedArray[Byte] {
  if row >= self.rows.length() {
    return FixedArray::make(0, 0)
  }
  let r = self.rows[row]
  if col >= r.length() {
    return FixedArray::make(0, 0)
  }
  slice(self.data, r[col].0, r[col].1)
}

///|
/// Sum of column `col` over rows whose cell parses as an integer.
pub fn Table::sum_int(self : Table, col : Int) -> Int64 {
  let mut total : Int64 = 0
  for r in self.rows {
    if col < r.length() {
      match @atoi.parse_int64(slice(self.data, r[col].0, r[col].1)) {
        Some(v) => total = total + v
        None => ()
      }
    }
  }
  total
}

///|
/// Number of cells in `col` that parse as integers.
pub fn Table::count_int(self : Table, col : Int) -> Int {
  let mut c = 0
  for r in self.rows {
    if col < r.length() {
      match @atoi.parse_int64(slice(self.data, r[col].0, r[col].1)) {
        Some(_) => c = c + 1
        None => ()
      }
    }
  }
  c
}

///|
/// Maximum integer in `col`, or `None` if no cell parses as one.
pub fn Table::max_int(self : Table, col : Int) -> Int64? {
  let mut best : Int64? = None
  for r in self.rows {
    if col < r.length() {
      match @atoi.parse_int64(slice(self.data, r[col].0, r[col].1)) {
        Some(v) =>
          best = match best {
            None => Some(v)
            Some(b) => Some(if v > b { v } else { b })
          }
        None => ()
      }
    }
  }
  best
}

///|
/// Minimum integer in `col`, or `None` if no cell parses as one.
pub fn Table::min_int(self : Table, col : Int) -> Int64? {
  let mut best : Int64? = None
  for r in self.rows {
    if col < r.length() {
      match @atoi.parse_int64(slice(self.data, r[col].0, r[col].1)) {
        Some(v) =>
          best = match best {
            None => Some(v)
            Some(b) => Some(if v < b { v } else { b })
          }
        None => ()
      }
    }
  }
  best
}

///|
/// Mean of the integer cells in `col`, or `None` if there are none.
pub fn Table::mean_int(self : Table, col : Int) -> Double? {
  let c = self.count_int(col)
  if c == 0 {
    None
  } else {
    Some(self.sum_int(col).to_double() / c.to_double())
  }
}
