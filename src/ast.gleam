import gleam/dict
import span
import token

pub type Expr =
  #(ExprType, span.Span)

pub type ExprType {
  Int(Int)
  Str(String)
  Bool(Bool)
  Nil
  Op(token.Op)
  KeyWord(token.KeyWord)
  Ident(String)
  Sexpr(List(Expr))
  //Params(Sexpr(#(token.Type, Expr)))
  Params(dict.Dict(Expr, #(token.Type, Int)))
  Type(token.Type)
}
