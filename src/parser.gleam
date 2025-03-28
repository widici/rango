import ast
import gleam/dict
import gleam/list
import gleam/option
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
    [token.Ident(ident), ..rest] -> #(ast.Ident(ident), rest)
    [token.Op(op), ..rest] -> #(ast.Op(op), rest)
    [token.Int(int), ..rest] -> #(ast.Int(int), rest)
    [token.Str(str), ..rest] -> #(ast.Str(str), rest)
    [token.Bool(bool), ..rest] -> #(ast.Bool(bool), rest)
    [token.Type(ttype), ..rest] -> #(ast.Type(ttype), rest)
    [token.LParen, ..rest] -> parse_list(rest, [])
    [token.LSquare, ..rest] -> parse_args(rest, option.None, dict.new())
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

fn parse_args(
  tokens: List(token.Token),
  param_type: option.Option(token.Type),
  acc: dict.Dict(ast.Expr, #(token.Type, Int)),
) -> #(ast.Expr, List(token.Token)) {
  case tokens {
    [token.RSquare, ..rest] -> #(ast.Params(acc), rest)
    [token.Type(param_type), ..rest] ->
      parse_args(rest, option.Some(param_type), acc)
    _ -> {
      let assert option.Some(param_type) = param_type
      let #(expr, rest) = parse_expr(tokens)
      parse_args(
        rest,
        option.Some(param_type),
        dict.insert(acc, expr, #(param_type, dict.size(acc))),
      )
    }
  }
}
