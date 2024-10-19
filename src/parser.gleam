import ast
import gleam/iterator
import gleam/list
import gleam/option
import token

pub opaque type Parser {
  Parser(tokens: List(token.TokenType))
}

pub fn new(tokens: List(token.TokenType)) {
  Parser(tokens)
}

pub fn parse(parser: Parser) -> iterator.Iterator(ast.Expr) {
  parse_exprs(parser, False)
}

fn parse_exprs(parser: Parser, is_inner: Bool) -> iterator.Iterator(ast.Expr) {
  use parser <- iterator.unfold(parser)
  case parse_expr(parser, is_inner) {
    #(_parser, option.None) -> iterator.Done
    #(parser, option.Some(expr)) -> iterator.Next(expr, parser)
  }
}

fn parse_expr(
  parser: Parser,
  is_inner: Bool,
) -> #(Parser, option.Option(ast.Expr)) {
  case parser.tokens {
    [first, ..rest] ->
      case first {
        token.LParen -> {
          let exprs = advance(rest) |> parse_exprs(True) |> iterator.to_list
          #(
            parser.tokens |> list.drop(list.length(exprs) + 1) |> advance,
            option.Some(ast.List(exprs)),
          )
        }
        token.RParen ->
          case is_inner {
            True -> #(advance(rest), option.None)
            False -> advance(rest) |> parse_expr(False)
          }
        token.Atom(atom) -> #(advance(rest), option.Some(ast.Atom(atom)))
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
