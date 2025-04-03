import ast
import span
import token

pub type Error {
  UnexpectedChar(span: span.Span)
  AmbigousTokenization(span: span.Span)
  UnexpectedToken(token_type: token.TokenType, span: span.Span)
  NotFound(name: String, span: span.Span)
  UnexpectedList(span: span.Span)
  UnexpectedExpr(expr_type: ast.ExprType, span: span.Span)
}
