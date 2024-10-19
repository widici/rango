import token

pub type Expr {
  Atom(token.Atom)
  Op(token.Op)
  List(List(Expr))
}
