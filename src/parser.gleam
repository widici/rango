import ast
import gleam/list
import gleam/option
import token

pub type Parser {
  Parser(tokens: List(token.TokenType))
}

pub fn parse(parser: Parser) -> List(ast.Expr) {
  let #(_parser, exprs) = parse_exprs(parser, False)
  exprs
}

fn parse_exprs(parser: Parser, is_inner: Bool) -> #(Parser, List(ast.Expr)) {
  let #(parser, exprs) =
    list.map_fold(parser.tokens, parser, fn(parser, _) {
      parse_expr(parser, is_inner)
    })
  #(parser, exprs |> option.values)
}

fn parse_expr(
  parser: Parser,
  is_inner: Bool,
) -> #(Parser, option.Option(ast.Expr)) {
  case parser.tokens {
    [first, ..rest] ->
      case first {
        token.KeyWord(keyword) -> #(
          advance(rest),
          option.Some(ast.KeyWord(keyword)),
        )
        token.LParen -> {
          let #(parser, exprs) = advance(rest) |> parse_exprs(True)
          #(parser, option.Some(ast.List(exprs)))
        }
        token.RParen ->
          case is_inner {
            True -> #(advance(rest), option.None)
            False -> advance(rest) |> parse_expr(False)
          }
        token.Atom(atom) -> #(
          advance(rest),
          option.Some(case atom {
            token.Int(int) -> ast.Int(int)
            token.Str(str) -> ast.Str(str)
            token.Bool(bool) -> ast.Bool(bool)
          }),
        )
        token.Op(op) -> #(advance(rest), option.Some(ast.Op(op)))
        token.EOF -> #(parser, option.None)
      }
    [] -> #(parser, option.None)
  }
}

// TODO: add offset in the future
fn advance(rest: List(token.TokenType)) -> Parser {
  Parser(tokens: rest)
}
