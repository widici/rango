import error
import gleam/int
import gleam/list
import gleam/option
import gleam/regex
import gleam/result
import gleam/string
import span
import token

pub opaque type Lexer {
  Lexer(src: String, pos: #(Int, Int), file_path: String)
}

pub fn new(src: String, file_path: String) -> Lexer {
  Lexer(src:, pos: #(1, 1), file_path:)
}

pub fn lex(lexer: Lexer) -> Result(List(token.Token), error.Error) {
  use tokens <- result.try(lex_(lexer))
  Ok(
    tokens
    |> list.filter(fn(x) { option.is_some(x.0) })
    |> list.map(fn(x) {
      let assert option.Some(token_type) = x.0
      #(token_type, x.1)
    }),
  )
}

fn lex_(
  lexer: Lexer,
) -> Result(List(#(option.Option(token.TokenType), span.Span)), error.Error) {
  use #(token_type, rest) <- result.try(lex_token(
    lexer.src,
    span.Span(start: lexer.pos, end: lexer.pos, file_path: lexer.file_path),
  ))
  let curr_len = string.length(rest)
  let assert Ok(#(grapheme, _)) = lexer.src |> string.pop_grapheme()
  let end = case grapheme {
    "\n" -> #(lexer.pos.0 + 1, 1)
    "\t" -> #(lexer.pos.0, lexer.pos.1 + 4)
    _ -> #(lexer.pos.0, lexer.pos.1 + { string.length(lexer.src) - curr_len })
  }
  let span =
    span.Span(
      start: lexer.pos,
      end: #(end.0, end.1 - 1),
      file_path: lexer.file_path,
    )
  case curr_len {
    0 -> Ok([#(token_type, span)])
    _ -> {
      use acc <- result.try(lex_(Lexer(..lexer, src: rest, pos: end)))
      Ok([#(token_type, span), ..acc])
    }
  }
}

fn lex_token(
  src: String,
  curr_pos: span.Span,
) -> Result(#(option.Option(token.TokenType), String), error.Error) {
  case src {
    " " <> rest | "\n" <> rest | "\t" <> rest -> Ok(#(option.None, rest))
    "+" <> rest -> Ok(#(option.Some(token.Op(token.Add)), rest))
    "-" <> rest -> Ok(#(option.Some(token.Op(token.Sub)), rest))
    "*" <> rest -> Ok(#(option.Some(token.Op(token.Mul)), rest))
    "/" <> rest -> Ok(#(option.Some(token.Op(token.Div)), rest))
    // Comparison operators
    "==" <> rest -> Ok(#(option.Some(token.Op(token.EqEq)), rest))
    "!=" <> rest -> Ok(#(option.Some(token.Op(token.Ne)), rest))
    ">" <> rest -> Ok(#(option.Some(token.Op(token.Gt)), rest))
    "<" <> rest -> Ok(#(option.Some(token.Op(token.Lt)), rest))
    ">=" <> rest -> Ok(#(option.Some(token.Op(token.Ge)), rest))
    "<=" <> rest -> Ok(#(option.Some(token.Op(token.Le)), rest))
    // Logical operators
    "and" <> rest -> Ok(#(option.Some(token.Op(token.And)), rest))
    "or" <> rest -> Ok(#(option.Some(token.Op(token.Or)), rest))
    "!" <> rest -> Ok(#(option.Some(token.Op(token.Not)), rest))
    // Parantheses
    "(" <> rest -> Ok(#(option.Some(token.LParen), rest))
    ")" <> rest -> Ok(#(option.Some(token.RParen), rest))
    // Square-brackets
    "[" <> rest -> Ok(#(option.Some(token.LSquare), rest))
    "]" <> rest -> Ok(#(option.Some(token.RSquare), rest))
    // Booleans
    "True" <> rest -> Ok(#(option.Some(token.Bool(True)), rest))
    "False" <> rest -> Ok(#(option.Some(token.Bool(False)), rest))
    // Types
    "Int" <> rest -> Ok(#(option.Some(token.Type(token.IntType)), rest))
    "Str" <> rest -> Ok(#(option.Some(token.Type(token.StrType)), rest))
    "Bool" <> rest -> Ok(#(option.Some(token.Type(token.BoolType)), rest))
    // Keywords
    "use" <> rest -> Ok(#(option.Some(token.KeyWord(token.Use)), rest))
    "fn" <> rest -> Ok(#(option.Some(token.KeyWord(token.Func)), rest))
    "ret" <> rest -> Ok(#(option.Some(token.KeyWord(token.Return)), rest))
    "var" <> rest -> Ok(#(option.Some(token.KeyWord(token.Var)), rest))
    "list" <> rest -> Ok(#(option.Some(token.KeyWord(token.List)), rest))
    "cons" <> rest -> Ok(#(option.Some(token.KeyWord(token.Cons)), rest))
    "\"" <> rest -> {
      let #(token, rest) = lex_str(rest)
      Ok(#(option.Some(token), rest))
    }
    _ -> {
      let assert Ok(#(grapheme, _)) = string.pop_grapheme(src)
      let funcs =
        [#("-?\\d+", lex_int), #("^[a-zA-Z_][a-zA-Z0-9_]*$", lex_ident)]
        |> list.map(fn(x) {
          case regex_validate(grapheme, x.0) {
            True -> option.Some(x.1)
            False -> option.None
          }
        })
        |> option.values()
      case funcs {
        [] -> Error(error.Error(error.UnexpectedChar, curr_pos))
        [func] -> {
          let #(token, rest) = func(src)
          Ok(#(option.Some(token), rest))
        }
        _ -> Error(error.Error(error.AmbigousTokenization, curr_pos))
      }
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

fn lex_str(src: String) -> #(token.TokenType, String) {
  let #(contents, rest) =
    take_predicate(src, "", fn(grapheme) {
      regex_validate(grapheme, "^[^\"]+$")
    })
  let assert Ok(#("\"", rest)) = string.pop_grapheme(rest)
  #(token.Str(contents), rest)
}

fn lex_int(src: String) -> #(token.TokenType, String) {
  let #(contents, rest) =
    take_predicate(src, "", fn(grapheme) { regex_validate(grapheme, "-?\\d+") })
  let assert Ok(contents) = int.parse(contents)
  #(token.Int(contents), rest)
}

fn lex_ident(src: String) -> #(token.TokenType, String) {
  let #(name, rest) =
    take_predicate(src, "", fn(grapheme) {
      regex_validate(grapheme, "^[a-zA-Z_][a-zA-Z0-9_]*$")
    })
  #(token.Ident(name), rest)
}
