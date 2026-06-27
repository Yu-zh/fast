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
#warnings("-unused_constructor")
priv enum TokenKind {
  ObjectStart
  ObjectEnd
  ArrayStart
  ArrayEnd
  ColonToken
  CommaToken
  StringToken
  NumberToken
  TrueToken
  FalseToken
  NullToken
}

///|
#warnings("-unused_field")
priv struct Token {
  pos : Int
  end : Int
  kind : TokenKind
}

///|
pub(all) suberror ParseError {
  UnexpectedEof(pos~ : Int)
  UnexpectedChar(pos~ : Int, expected~ : String, found~ : Byte)
  InvalidString(pos~ : Int, message~ : String)
  InvalidNumber(pos~ : Int, lexeme~ : String)
  TrailingContent(pos~ : Int)
  NestingTooDeep(pos~ : Int, limit~ : Int)
} derive(Debug, Eq, ToJson)
