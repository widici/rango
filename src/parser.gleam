import ast
import gleam/iterator
import gleam/option
import token

pub opaque type Parser {
  Parser(tokens: List(token.TokenType))
}

pub fn new(tokens: List(token.TokenType)) {
  Parser(tokens)
}

pub fn parse(parser: Parser) -> iterator.Iterator(ast.Expr) {
  let #(_parser, exprs) = parse_exprs(parser, False)
  exprs
}

// TODO: handle getting the last parser accumulator in a better way
fn parse_exprs(
  parser: Parser,
  is_inner: Bool,
) -> #(Parser, iterator.Iterator(ast.Expr)) {
  let iter =
    iterator.unfold(parser, fn(parser) {
      case parse_expr(parser, is_inner) {
        #(_parser, option.None) -> iterator.Done
        #(parser, option.Some(expr)) -> iterator.Next(#(parser, expr), parser)
      }
    })

  let assert Ok(#(parser, _expr)) = iterator.last(iter)
  #(
    parser,
    iterator.map(iter, fn(x) {
      let #(_parser, expr) = x
      expr
    }),
  )
}

fn parse_expr(
  parser: Parser,
  is_inner: Bool,
) -> #(Parser, option.Option(ast.Expr)) {
  case parser.tokens {
    [first, ..rest] ->
      case first {
        token.LParen -> {
          let #(parser, exprs) = advance(rest) |> parse_exprs(True)
          #(parser, option.Some(ast.List(exprs |> iterator.to_list)))
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
