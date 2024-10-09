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
    "(" <> src -> #(advance(lexer, src, 1), token.LParen)
    ")" <> src -> #(advance(lexer, src, 1), token.RParen)
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
        False -> #(lexer, token.Int(contents))
      }
    Ok(#(grapheme, rest)) -> {
      let assert Ok(re) = regex.from_string("-?\\d+")
      case regex.check(re, grapheme) {
        True -> lex_int(advance(lexer, rest, 1), grapheme <> contents)
        False -> #(lexer, token.Int(contents))
      }
    }
  }
}

fn advance(lexer: Lexer, src: String, offset: Int) -> Lexer {
  Lexer(src, pos: lexer.pos + offset)
}
