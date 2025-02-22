import gleam/int
import gleam/iterator
import gleam/regex
import gleam/string
import token

pub opaque type Lexer {
  Lexer(src: String, pos: Int)
}

pub fn new(src: String) -> Lexer {
  Lexer(src, pos: 0)
}

pub fn lex(lexer: Lexer) -> iterator.Iterator(token.Token) {
  use lexer <- iterator.unfold(lexer)
  case lex_token(lexer) {
    #(_lexer, token.EOF) -> iterator.Done
    #(lexer, token) -> iterator.Next(token, lexer)
  }
}

fn lex_token(lexer: Lexer) -> #(Lexer, token.Token) {
  case lexer.src {
    "" -> #(lexer, token.EOF)
    " " <> src | "\n" <> src | "\t" <> src ->
      advance(lexer, src, 1) |> lex_token
    // Arthitmetic operators
    "+" <> src -> #(advance(lexer, src, 1), token.Op(token.Add))
    "-" <> src -> #(advance(lexer, src, 1), token.Op(token.Sub))
    "*" <> src -> #(advance(lexer, src, 1), token.Op(token.Mul))
    "/" <> src -> #(advance(lexer, src, 1), token.Op(token.Div))
    // Comparison operators
    "==" <> src -> #(advance(lexer, src, 2), token.Op(token.EqEq))
    "!=" <> src -> #(advance(lexer, src, 2), token.Op(token.Ne))
    ">" <> src -> #(advance(lexer, src, 1), token.Op(token.Gt))
    "<" <> src -> #(advance(lexer, src, 1), token.Op(token.Lt))
    ">=" <> src -> #(advance(lexer, src, 2), token.Op(token.Ge))
    "<=" <> src -> #(advance(lexer, src, 2), token.Op(token.Le))
    // Logical operators
    "and" <> src -> #(advance(lexer, src, 3), token.Op(token.And))
    "or" <> src -> #(advance(lexer, src, 2), token.Op(token.Or))
    "!" <> src -> #(advance(lexer, src, 1), token.Op(token.Not))
    // Parantheses
    "(" <> src -> #(advance(lexer, src, 1), token.LParen)
    ")" <> src -> #(advance(lexer, src, 1), token.RParen)
    // Booleans
    "True" <> src -> #(advance(lexer, src, 4), token.Bool(True))
    "False" <> src -> #(advance(lexer, src, 5), token.Bool(False))
    // Keywords
    "use" <> src -> #(advance(lexer, src, 6), token.KeyWord(token.Use))
    "\"" <> src -> advance(lexer, src, 1) |> lex_str("")
    _ -> {
      lex_int(lexer, "")
    }
  }
}

fn lex_int(lexer: Lexer, contents: String) -> #(Lexer, token.Token) {
  case string.pop_grapheme(lexer.src) {
    Error(_) ->
      case string.is_empty(contents) {
        True -> #(lexer, token.EOF)
        False -> {
          let assert Ok(data) = int.parse(contents)
          #(lexer, token.Int(data))
        }
      }
    Ok(#(grapheme, rest)) -> {
      let assert Ok(re) = regex.from_string("-?\\d+")
      case regex.check(re, grapheme) {
        True -> lex_int(advance(lexer, rest, 1), contents <> grapheme)
        False -> {
          let assert Ok(data) = int.parse(contents)
          #(lexer, token.Int(data))
        }
      }
    }
  }
}

fn lex_str(lexer: Lexer, contents: String) -> #(Lexer, token.Token) {
  case lexer.src {
    "" -> panic
    // "" should be handeled as a error in the future
    "\"" <> rest -> #(advance(lexer, rest, 1), token.Str(contents))
    str -> {
      let assert Ok(#(grapheme, rest)) = string.pop_grapheme(str)
      lex_str(advance(lexer, rest, 1), contents <> grapheme)
    }
  }
}

fn advance(lexer: Lexer, src: String, offset: Int) -> Lexer {
  Lexer(src, pos: lexer.pos + offset)
}
