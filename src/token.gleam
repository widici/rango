pub type TokenType {
  LParen
  RParen
  BinOp(BinOp)
  Int(String)
  EOF
}

pub type BinOp {
  Add
  Sub
  Mul
  Div
}
