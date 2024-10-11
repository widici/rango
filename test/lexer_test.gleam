import gleam/iterator
import gleeunit/should
import lexer
import token

pub fn int_arith_lex_test() {
  lex_test_helper("(+ 1 1)", [
    token.LParen,
    token.BinOp(token.Add),
    token.Int("1"),
    token.Int("1"),
    token.RParen,
  ])
  lex_test_helper("(* 2 (+ 1 1))", [
    token.LParen,
    token.BinOp(token.Mul),
    token.Int("2"),
    token.LParen,
    token.BinOp(token.Add),
    token.Int("1"),
    token.Int("1"),
    token.RParen,
    token.RParen,
  ])
  lex_test_helper("(+ (/ 2 (- 321 9)))", [
    token.LParen,
    token.BinOp(token.Add),
    token.LParen,
    token.BinOp(token.Div),
    token.Int("2"),
    token.LParen,
    token.BinOp(token.Sub),
    token.Int("321"),
    token.Int("9"),
    token.RParen,
    token.RParen,
    token.RParen,
  ])
}

fn lex_test_helper(input: String, output: List(token.TokenType)) {
  lexer.new(input) |> lexer.lex() |> iterator.to_list() |> should.equal(output)
}
