import ast
import gleam/list
import token

pub fn parse(tokens: List(token.Token)) -> List(ast.Expr) {
  let #(expr, rest) = parse_expr(tokens)
  case list.length(rest) {
    0 -> [expr]
    _ -> [expr, ..parse(rest)]
  }
}

fn parse_expr(tokens: List(token.Token)) -> #(ast.Expr, List(token.Token)) {
  case tokens {
    [token.KeyWord(keyword), ..rest] -> #(ast.KeyWord(keyword), rest)
    [token.Op(op), ..rest] -> #(ast.Op(op), rest)
    [token.Int(int), ..rest] -> #(ast.Int(int), rest)
    [token.Str(str), ..rest] -> #(ast.Str(str), rest)
    [token.Bool(bool), ..rest] -> #(ast.Bool(bool), rest)
    [token.LParen, ..rest] -> parse_list(rest, [])
    _ -> panic
  }
}

fn parse_list(
  tokens: List(token.Token),
  acc: List(ast.Expr),
) -> #(ast.Expr, List(token.Token)) {
  case tokens {
    [token.RParen, ..rest] -> #(ast.List(acc |> list.reverse()), rest)
    _ -> {
      let #(expr, rest) = parse_expr(tokens)
      parse_list(rest, [expr, ..acc])
    }
  }
}
