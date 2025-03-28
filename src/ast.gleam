import gleam/dict
import token

pub type Expr {
  Int(Int)
  Str(String)
  Bool(Bool)
  Op(token.Op)
  KeyWord(token.KeyWord)
  Ident(String)
  List(List(Expr))
  //Params(List(#(token.Type, Expr)))
  Params(dict.Dict(Expr, #(token.Type, Int)))
  Type(token.Type)
}
