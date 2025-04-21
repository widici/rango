import ast
import error
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import span
import token

pub fn parse(tokens: List(token.Token)) -> Result(List(ast.Expr), error.Error) {
  use #(expr, rest) <- result.try(parse_expr(tokens))
  case list.length(rest) {
    0 -> Ok([expr])
    _ -> {
      use acc <- result.try(parse(rest))
      Ok([expr, ..acc])
    }
  }
}

fn parse_expr(
  tokens: List(token.Token),
) -> Result(#(ast.Expr, List(token.Token)), error.Error) {
  case tokens {
    [#(token.KeyWord(keyword), span), ..rest] ->
      Ok(#(#(ast.KeyWord(keyword), span), rest))
    [#(token.Ident(ident), span), ..rest] ->
      Ok(#(#(ast.Ident(ident), span), rest))
    [#(token.Op(op), span), ..rest] -> Ok(#(#(ast.Op(op), span), rest))
    [#(token.Int(int), span), ..rest] -> Ok(#(#(ast.Int(int), span), rest))
    [#(token.Str(str), span), ..rest] -> Ok(#(#(ast.Str(str), span), rest))
    [#(token.Bool(bool), span), ..rest] -> Ok(#(#(ast.Bool(bool), span), rest))
    [#(token.Nil, span), ..rest] -> Ok(#(#(ast.Nil, span), rest))
    [#(token.Ok, span), ..rest] -> Ok(#(#(ast.Ok, span), rest))
    [#(token.Type(ttype), span), ..rest] ->
      Ok(#(#(ast.Type(ttype), span), rest))
    [#(token.LParen, span.Span(start, _, file_path)), ..rest] ->
      parse_list(rest, [], start, file_path)
    [#(token.LSquare, span.Span(start, _, file_path)), ..rest] ->
      parse_params(rest, option.None, dict.new(), start, file_path)
    _ -> {
      let assert Ok(#(token_type, span)) = list.first(tokens)
      Error(error.Error(error.UnexpectedToken(token_type:), span))
    }
  }
}

fn parse_list(
  tokens: List(token.Token),
  acc: List(ast.Expr),
  start: #(Int, Int),
  file_path: String,
) -> Result(#(ast.Expr, List(token.Token)), error.Error) {
  case tokens {
    [#(token.RParen, span.Span(_, end, new_path)), ..rest] -> {
      let assert True = file_path == new_path
      Ok(#(
        #(ast.Sexpr(acc |> list.reverse()), span.Span(start:, end:, file_path:)),
        rest,
      ))
    }
    _ -> {
      use #(expr, rest) <- result.try(parse_expr(tokens))
      parse_list(rest, [expr, ..acc], start, file_path)
    }
  }
}

fn parse_params(
  tokens: List(token.Token),
  param_type: option.Option(token.Type),
  acc: dict.Dict(ast.Expr, #(token.Type, Int)),
  start: #(Int, Int),
  file_path: String,
) -> Result(#(ast.Expr, List(token.Token)), error.Error) {
  case tokens {
    [#(token.RSquare, span.Span(_, end, new_path)), ..rest] -> {
      let assert True = file_path == new_path
      Ok(#(#(ast.Params(acc), span.Span(start:, end:, file_path:)), rest))
    }
    [#(token.Type(param_type), _), ..rest] ->
      parse_params(rest, option.Some(param_type), acc, start, file_path)
    _ -> {
      let assert option.Some(param_type) = param_type
      use #(expr, rest) <- result.try(parse_expr(tokens))
      parse_params(
        rest,
        option.Some(param_type),
        dict.insert(acc, expr, #(param_type, dict.size(acc))),
        start,
        file_path,
      )
    }
  }
}
