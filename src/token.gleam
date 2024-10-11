pub type TokenType {
  LParen
  RParen
  BinOp(BinOp)
  Int(String)
  Str(String)
  EOF
}

pub type BinOp {
  Add
  Sub
  Mul
  Div
}
