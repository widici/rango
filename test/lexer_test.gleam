import gleam/iterator
import gleeunit/should
import lexer
import token

pub fn int_arith_lex_test() {
  lex_test_helper("(+ 1 1)", [
    token.LParen,
    token.BinOp(token.Add),
    token.Atom(token.Int("1")),
    token.Atom(token.Int("1")),
    token.RParen,
  ])
  lex_test_helper("(* 2 (+ 1 1))", [
    token.LParen,
    token.BinOp(token.Mul),
    token.Atom(token.Int("2")),
    token.LParen,
    token.BinOp(token.Add),
    token.Atom(token.Int("1")),
    token.Atom(token.Int("1")),
    token.RParen,
    token.RParen,
  ])
  lex_test_helper("(+ (/ 2 (- 321 9)))", [
    token.LParen,
    token.BinOp(token.Add),
    token.LParen,
    token.BinOp(token.Div),
    token.Atom(token.Int("2")),
    token.LParen,
    token.BinOp(token.Sub),
    token.Atom(token.Int("321")),
    token.Atom(token.Int("9")),
    token.RParen,
    token.RParen,
    token.RParen,
  ])
}

pub fn str_lex_test() {
  lex_test_helper("\"abcdefg\"", [token.Atom(token.Str("abcdefg"))])
  lex_test_helper("\"\n\t\"", [token.Atom(token.Str("\n\t"))])
  lex_test_helper("\"\"\"\"", [
    token.Atom(token.Str("")),
    token.Atom(token.Str("")),
  ])
  lex_test_helper("(+ \"example str\" 99)", [
    token.LParen,
    token.BinOp(token.Add),
    token.Atom(token.Str("example str")),
    token.Atom(token.Int("99")),
    token.RParen,
  ])
}

fn lex_test_helper(input: String, output: List(token.TokenType)) {
  lexer.new(input) |> lexer.lex() |> iterator.to_list() |> should.equal(output)
}
