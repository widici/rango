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

pub fn lex(lexer: Lexer) -> iterator.Iterator(token.TokenType) {
  use lexer <- iterator.unfold(lexer)
  case lexer |> lex_token() {
    #(_lexer, token.EOF) -> iterator.Done
    #(lexer, token) -> iterator.Next(token, lexer)
  }
}

fn lex_token(lexer: Lexer) -> #(Lexer, token.TokenType) {
  case lexer.src {
    "" -> #(lexer, token.EOF)
    " " <> src | "\n" <> src | "\t" <> src ->
      advance(lexer, src, 1) |> lex_token()
    "+" <> src -> #(advance(lexer, src, 1), token.BinOp(token.Add))
    "-" <> src -> #(advance(lexer, src, 1), token.BinOp(token.Sub))
    "*" <> src -> #(advance(lexer, src, 1), token.BinOp(token.Mul))
    "/" <> src -> #(advance(lexer, src, 1), token.BinOp(token.Div))
    "==" <> src -> #(advance(lexer, src, 2), token.BinOp(token.EqEq))
    "!=" <> src -> #(advance(lexer, src, 2), token.BinOp(token.Ne))
    ">" <> src -> #(advance(lexer, src, 1), token.BinOp(token.Gt))
    "<" <> src -> #(advance(lexer, src, 1), token.BinOp(token.Lt))
    ">=" <> src -> #(advance(lexer, src, 2), token.BinOp(token.Ge))
    "<=" <> src -> #(advance(lexer, src, 2), token.BinOp(token.Le))
    "and" <> src -> #(advance(lexer, src, 3), token.BinOp(token.And))
    "or" <> src -> #(advance(lexer, src, 2), token.BinOp(token.Or))
    "!" <> src -> #(advance(lexer, src, 1), token.UnOp(token.Not))
    "(" <> src -> #(advance(lexer, src, 1), token.LParen)
    ")" <> src -> #(advance(lexer, src, 1), token.RParen)
    "True" <> src -> #(advance(lexer, src, 4), token.Atom(token.Bool(True)))
    "False" <> src -> #(advance(lexer, src, 5), token.Atom(token.Bool(False)))
    "\"" <> src -> advance(lexer, src, 1) |> lex_str("")
    _ -> {
      lex_int(lexer, "")
    }
  }
}

fn lex_int(lexer: Lexer, contents: String) -> #(Lexer, token.TokenType) {
  case string.pop_grapheme(lexer.src) {
    Error(_) ->
      case string.is_empty(contents) {
        True -> #(lexer, token.EOF)
        False -> #(lexer, token.Atom(token.Int(contents)))
      }
    Ok(#(grapheme, rest)) -> {
      let assert Ok(re) = regex.from_string("-?\\d+")
      case regex.check(re, grapheme) {
        True -> lex_int(advance(lexer, rest, 1), contents <> grapheme)
        False -> #(lexer, token.Atom(token.Int(contents)))
      }
    }
  }
}

fn lex_str(lexer: Lexer, contents: String) -> #(Lexer, token.TokenType) {
  case lexer.src {
    "" -> panic
    // "" should be handeled as a error in the future
    "\"" <> rest -> #(advance(lexer, rest, 1), token.Atom(token.Str(contents)))
    str -> {
      let assert Ok(#(grapheme, rest)) = string.pop_grapheme(str)
      lex_str(advance(lexer, rest, 1), contents <> grapheme)
    }
  }
}

fn advance(lexer: Lexer, src: String, offset: Int) -> Lexer {
  Lexer(src, pos: lexer.pos + offset)
}
