import token

pub type Expr {
  Int(Int)
  Str(String)
  Bool(Bool)
  Op(token.Op)
  KeyWord(token.KeyWord)
  List(List(Expr))
}
