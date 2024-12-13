import ast
import gleam/iterator
import gleeunit/should
import parser
import token

pub fn int_arith_parse_test() {
  [
    token.LParen,
    token.Op(token.Add),
    token.Atom(token.Int("1")),
    token.Atom(token.Int("1")),
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([ast.Op(token.Add), ast.Int("1"), ast.Int("1")]),
  ])

  [
    token.LParen,
    token.Op(token.Mul),
    token.Atom(token.Int("2")),
    token.LParen,
    token.Op(token.Add),
    token.Atom(token.Int("1")),
    token.Atom(token.Int("1")),
    token.RParen,
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.Op(token.Mul),
      ast.Int("2"),
      ast.List([ast.Op(token.Add), ast.Int("1"), ast.Int("1")]),
    ]),
  ])

  [
    token.LParen,
    token.Op(token.Add),
    token.LParen,
    token.Op(token.Div),
    token.Atom(token.Int("2")),
    token.LParen,
    token.Op(token.Sub),
    token.Atom(token.Int("321")),
    token.Atom(token.Int("9")),
    token.RParen,
    token.RParen,
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.Op(token.Add),
      ast.List([
        ast.Op(token.Div),
        ast.Int("2"),
        ast.List([ast.Op(token.Sub), ast.Int("321"), ast.Int("9")]),
      ]),
    ]),
  ])
}

fn parse_test_helper(input: List(token.TokenType), output: List(ast.Expr)) {
  parser.Parser(input)
  |> parser.parse
  |> iterator.to_list
  |> should.equal(output)
}
