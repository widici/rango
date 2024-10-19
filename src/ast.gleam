import token

pub type Expr {
  Int(String)
  Str(String)
  Bool(Bool)
  Op(token.Op)
  List(List(Expr))
}
