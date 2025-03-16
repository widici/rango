import ast
import gleeunit/should
import parser
import token

pub fn int_arith_parse_test() {
  [token.LParen, token.Op(token.Add), token.Int(1), token.Int(1), token.RParen]
  |> parse_test_helper([ast.List([ast.Op(token.Add), ast.Int(1), ast.Int(1)])])

  [
    token.LParen,
    token.Op(token.Mul),
    token.Int(2),
    token.LParen,
    token.Op(token.Add),
    token.Int(1),
    token.Int(1),
    token.RParen,
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.Op(token.Mul),
      ast.Int(2),
      ast.List([ast.Op(token.Add), ast.Int(1), ast.Int(1)]),
    ]),
  ])

  [
    token.LParen,
    token.Op(token.Add),
    token.LParen,
    token.Op(token.Div),
    token.Int(2),
    token.LParen,
    token.Op(token.Sub),
    token.Int(321),
    token.Int(9),
    token.RParen,
    token.RParen,
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.Op(token.Add),
      ast.List([
        ast.Op(token.Div),
        ast.Int(2),
        ast.List([ast.Op(token.Sub), ast.Int(321), ast.Int(9)]),
      ]),
    ]),
  ])

  [
    token.LParen,
    token.Op(token.Mul),
    token.LParen,
    token.Op(token.Add),
    token.Int(1),
    token.Int(1),
    token.RParen,
    token.Int(2),
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.Op(token.Mul),
      ast.List([ast.Op(token.Add), ast.Int(1), ast.Int(1)]),
      ast.Int(2),
    ]),
  ])
}

pub fn parse_func_test() {
  [
    token.LParen,
    token.KeyWord(token.Func),
    token.Ident("add"),
    token.LSquare,
    token.Type(token.IntType),
    token.Ident("a"),
    token.Ident("b"),
    token.RSquare,
    token.Type(token.IntType),
    token.LParen,
    token.Op(token.Add),
    token.Int(1),
    token.Int(2),
    token.RParen,
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.KeyWord(token.Func),
      ast.Ident("add"),
      ast.Params([
        #(token.IntType, ast.Ident("a")),
        #(token.IntType, ast.Ident("b")),
      ]),
      ast.Type(token.IntType),
      ast.List([ast.Op(token.Add), ast.Int(1), ast.Int(2)]),
    ]),
  ])

  [
    token.LParen,
    token.KeyWord(token.Func),
    token.Ident("f"),
    token.LSquare,
    token.RSquare,
    token.Type(token.IntType),
    token.Int(0),
    token.RParen,
  ]
  |> parse_test_helper([
    ast.List([
      ast.KeyWord(token.Func),
      ast.Ident("f"),
      ast.Params([]),
      ast.Type(token.IntType),
      ast.Int(0),
    ]),
  ])
}

fn parse_test_helper(input: List(token.Token), output: List(ast.Expr)) {
  input
  |> parser.parse()
  |> should.equal(output)
}
