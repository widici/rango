import gleam/int
import gleam/list
import gleam/option
import gleam/regex
import gleam/string
import token

pub opaque type Lexer {
  Lexer(src: String, pos: Int)
}

pub fn new(src: String) -> Lexer {
  Lexer(src, pos: 0)
}

pub fn lex(lexer: Lexer) -> List(token.Token) {
  lex_(lexer) |> option.values()
}

fn lex_(lexer: Lexer) -> List(option.Option(token.Token)) {
  let prev_len = string.length(lexer.src)
  let #(token, rest) = lex_token(lexer.src)
  let curr_len = string.length(rest)
  case curr_len {
    0 -> [token]
    _ -> [
      token,
      ..lex_(Lexer(src: rest, pos: lexer.pos + { prev_len - curr_len }))
    ]
  }
}

fn lex_token(src: String) -> #(option.Option(token.Token), String) {
  case src {
    " " <> rest | "\n" <> rest | "\t" <> rest -> #(option.None, rest)
    "+" <> rest -> #(option.Some(token.Op(token.Add)), rest)
    "-" <> rest -> #(option.Some(token.Op(token.Sub)), rest)
    "*" <> rest -> #(option.Some(token.Op(token.Mul)), rest)
    "/" <> rest -> #(option.Some(token.Op(token.Div)), rest)
    // Comparison operators
    "==" <> rest -> #(option.Some(token.Op(token.EqEq)), rest)
    "!=" <> rest -> #(option.Some(token.Op(token.Ne)), rest)
    ">" <> rest -> #(option.Some(token.Op(token.Gt)), rest)
    "<" <> rest -> #(option.Some(token.Op(token.Lt)), rest)
    ">=" <> rest -> #(option.Some(token.Op(token.Ge)), rest)
    "<=" <> rest -> #(option.Some(token.Op(token.Le)), rest)
    // Logical operators
    "and" <> rest -> #(option.Some(token.Op(token.And)), rest)
    "or" <> rest -> #(option.Some(token.Op(token.Or)), rest)
    "!" <> rest -> #(option.Some(token.Op(token.Not)), rest)
    // Parantheses
    "(" <> rest -> #(option.Some(token.LParen), rest)
    ")" <> rest -> #(option.Some(token.RParen), rest)
    // Square-brackets
    "[" <> rest -> #(option.Some(token.LSquare), rest)
    "]" <> rest -> #(option.Some(token.RSquare), rest)
    // Booleans
    "True" <> rest -> #(option.Some(token.Bool(True)), rest)
    "False" <> rest -> #(option.Some(token.Bool(False)), rest)
    // Types
    "Int" <> rest -> #(option.Some(token.Type(token.IntType)), rest)
    "Str" <> rest -> #(option.Some(token.Type(token.StrType)), rest)
    "Bool" <> rest -> #(option.Some(token.Type(token.BoolType)), rest)
    // Keywords
    "use" <> rest -> #(option.Some(token.KeyWord(token.Use)), rest)
    "fn" <> rest -> #(option.Some(token.KeyWord(token.Func)), rest)
    "\"" <> rest -> {
      let #(token, rest) = lex_str(rest)
      #(option.Some(token), rest)
    }
    _ -> {
      let assert Ok(#(grapheme, _)) = string.pop_grapheme(src)
      let assert Ok(func) =
        [#("-?\\d+", lex_int), #("^[a-zA-Z_][a-zA-Z0-9_]*$", lex_ident)]
        |> list.map(fn(x) {
          case regex_validate(grapheme, x.0) {
            True -> option.Some(x.1)
            False -> option.None
          }
        })
        |> option.values()
        |> list.first()
      let #(token, rest) = func(src)
      #(option.Some(token), rest)
    }
  }
}

fn take_predicate(
  src: String,
  acc: String,
  predicate: fn(String) -> Bool,
) -> #(String, String) {
  case string.pop_grapheme(src) {
    Ok(#(grapheme, rest)) -> {
      case predicate(grapheme) {
        True -> take_predicate(rest, acc <> grapheme, predicate)
        False -> #(acc, src)
      }
    }
    Error(_) -> #(acc, "")
  }
}

fn regex_validate(grapheme: String, re: String) -> Bool {
  let assert Ok(re) = regex.from_string(re)
  regex.check(re, grapheme)
}

fn lex_str(src: String) -> #(token.Token, String) {
  let #(contents, rest) =
    take_predicate(src, "", fn(grapheme) {
      regex_validate(grapheme, "^[^\"]+$")
    })
  let assert Ok(#("\"", rest)) = string.pop_grapheme(rest)
  #(token.Str(contents), rest)
}

fn lex_int(src: String) -> #(token.Token, String) {
  let #(contents, rest) =
    take_predicate(src, "", fn(grapheme) { regex_validate(grapheme, "-?\\d+") })
  let assert Ok(contents) = int.parse(contents)
  #(token.Int(contents), rest)
}

fn lex_ident(src: String) -> #(token.Token, String) {
  let #(name, rest) =
    take_predicate(src, "", fn(grapheme) {
      regex_validate(grapheme, "^[a-zA-Z_][a-zA-Z0-9_]*$")
    })
  #(token.Ident(name), rest)
}
