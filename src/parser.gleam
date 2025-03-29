import ast
import gleam/dict
import gleam/list
import gleam/option
import span
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
    [#(token.KeyWord(keyword), span), ..rest] -> #(
      #(ast.KeyWord(keyword), span),
      rest,
    )
    [#(token.Ident(ident), span), ..rest] -> #(#(ast.Ident(ident), span), rest)
    [#(token.Op(op), span), ..rest] -> #(#(ast.Op(op), span), rest)
    [#(token.Int(int), span), ..rest] -> #(#(ast.Int(int), span), rest)
    [#(token.Str(str), span), ..rest] -> #(#(ast.Str(str), span), rest)
    [#(token.Bool(bool), span), ..rest] -> #(#(ast.Bool(bool), span), rest)
    [#(token.Type(ttype), span), ..rest] -> #(#(ast.Type(ttype), span), rest)
    [#(token.LParen, span.Span(start, _)), ..rest] ->
      parse_list(rest, [], start)
    [#(token.LSquare, span.Span(start, _)), ..rest] ->
      parse_args(rest, option.None, dict.new(), start)
    _ -> panic
  }
}

fn parse_list(
  tokens: List(token.Token),
  acc: List(ast.Expr),
  start: Int,
) -> #(ast.Expr, List(token.Token)) {
  case tokens {
    [#(token.RParen, span.Span(_, end)), ..rest] -> #(
      #(ast.List(acc |> list.reverse()), span.Span(start:, end:)),
      rest,
    )
    _ -> {
      let #(expr, rest) = parse_expr(tokens)
      parse_list(rest, [expr, ..acc], start)
    }
  }
}

fn parse_args(
  tokens: List(token.Token),
  param_type: option.Option(token.Type),
  acc: dict.Dict(ast.Expr, #(token.Type, Int)),
  start: Int,
) -> #(ast.Expr, List(token.Token)) {
  case tokens {
    [#(token.RSquare, span.Span(_, end)), ..rest] -> #(
      #(ast.Params(acc), span.Span(start:, end:)),
      rest,
    )
    [#(token.Type(param_type), _), ..rest] ->
      parse_args(rest, option.Some(param_type), acc, start)
    _ -> {
      let assert option.Some(param_type) = param_type
      let #(expr, rest) = parse_expr(tokens)
      parse_args(
        rest,
        option.Some(param_type),
        dict.insert(acc, expr, #(param_type, dict.size(acc))),
        start,
      )
    }
  }
}
