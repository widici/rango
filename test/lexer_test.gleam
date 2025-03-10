import gleeunit/should
import lexer
import token

pub fn int_arith_lex_test() {
  lex_test_helper("(+ 1 1)", [
    token.LParen,
    token.Op(token.Add),
    token.Int(1),
    token.Int(1),
    token.RParen,
  ])
  lex_test_helper("(* 2 (+ 1 1))", [
    token.LParen,
    token.Op(token.Mul),
    token.Int(2),
    token.LParen,
    token.Op(token.Add),
    token.Int(1),
    token.Int(1),
    token.RParen,
    token.RParen,
  ])
  lex_test_helper("(+ (/ 2 (- 321 9)))", [
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
  ])
}

pub fn str_lex_test() {
  lex_test_helper("\"abcdefg\"", [token.Str("abcdefg")])
  lex_test_helper("\"\n\t\"", [token.Str("\n\t")])
  lex_test_helper("\"\"\"\"", [token.Str(""), token.Str("")])
  lex_test_helper("(+ \"example str\" 99)", [
    token.LParen,
    token.Op(token.Add),
    token.Str("example str"),
    token.Int(99),
    token.RParen,
  ])
}

pub fn bool_lex_test() {
  lex_test_helper("True False", [token.Bool(True), token.Bool(False)])
  lex_test_helper("(!= (! True) False)", [
    token.LParen,
    token.Op(token.Ne),
    token.LParen,
    token.Op(token.Not),
    token.Bool(True),
    token.RParen,
    token.Bool(False),
    token.RParen,
  ])
}

fn lex_test_helper(input: String, output: List(token.Token)) {
  lexer.new(input) |> lexer.lex() |> should.equal(output)
}
