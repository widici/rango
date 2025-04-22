import ast
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
  AmbigousCall(name: String, arity: Int)
  MissingFunc(name: String, arity: Int)
  RedundantImporting(module: String, name: String, arity: Int)
  ImportConflict(module: String, name: String, arity: Int)
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
    NotFound(name) -> #(name <> " not found in this context", [])
    UnexpectedList(list) -> #(
      "List: " <> pprint.format(list) <> " unexpected in this context",
      [],
    )
    UnexpectedExpr(expr) -> #(
      "Expr: " <> pprint.format(expr) <> " in this context",
      [],
    )
    AmbigousCall(name, arity) -> #("Ambigous function call used", [
      report.Text(
        "Function "
        <> name
        <> ":"
        <> pprint.format(arity)
        <> " fits the criteria of multiple different functions",
      ),
    ])
    MissingFunc(name, arity) -> #("Missing function called", [
      report.Text(
        "Function "
        <> name
        <> ":"
        <> pprint.format(arity)
        <> " is missing and therefore can't be called",
      ),
    ])
    RedundantImporting(module, name, arity) -> #("Redundant function import", [
      report.Text(
        "Function "
        <> module
        <> "/"
        <> name
        <> ":"
        <> pprint.format(arity)
        <> " is already imported",
      ),
    ])
    ImportConflict(module, name, arity) -> #("Import conflict occured", [
      report.Text(
        "Function "
        <> module
        <> "/"
        <> name
        <> ":"
        <> pprint.format(arity)
        <> " caused an import conflict",
      ),
      report.Text(
        "Help: Change or remove other imports w/ the signature "
        <> name
        <> ":"
        <> pprint.format(arity),
      ),
    ])
  }
  let labels = [
    report.primary_label("found here", error.span.start, error.span.end),
  ]
  report.error(error.span.file_path, source, message, labels, info)
  |> report.to_string(style: True)
}
