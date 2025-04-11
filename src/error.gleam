import ast
import gleam/int
import pprint
import report
import simplifile
import span
import token

pub type Error {
  Error(error_type: ErrorType, span: span.Span)
}

pub type ErrorType {
  UnexpectedChar
  AmbigousTokenization
  UnexpectedToken(token_type: token.TokenType)
  NotFound(name: String)
  UnexpectedList(list: List(ast.ExprType))
  UnexpectedExpr(expr_type: ast.ExprType)
  InvalidArity(found: Int, expected: Int)
}

pub fn to_string(error: Error) -> String {
  let assert Ok(source) = simplifile.read(error.span.file_path)
  let #(message, info) = case error.error_type {
    UnexpectedChar -> #("Found a unexpected character", [
      report.Text(
        "Character does not fit any criteria for a valid lexible character",
      ),
    ])
    AmbigousTokenization -> #("Found a ambigous character", [
      report.Text(
        "Character fits into multiple criterias for a valid lexible character and therefore can't be lexed",
      ),
    ])
    UnexpectedToken(token_type) -> #(
      "Token: " <> pprint.format(token_type) <> " is unexpected in this context",
      [],
    )
    NotFound(name) -> #(name <> " not found in the context", [])
    UnexpectedList(list) -> #(
      "List: " <> pprint.format(list) <> " unexpected in the context",
      [],
    )
    UnexpectedExpr(expr) -> #(
      "Expr: " <> pprint.format(expr) <> " in the context",
      [],
    )
    InvalidArity(found, expected) -> #(
      "Unexpected arity, function expected arity: "
        <> int.to_string(expected)
        <> " caller used arity: "
        <> int.to_string(found),
      [],
    )
  }
  let labels = [
    report.primary_label("found here", error.span.start, error.span.end),
  ]
  report.error(error.span.file_path, source, message, labels, info)
  |> report.to_string(style: True)
}
