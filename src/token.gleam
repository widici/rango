pub type TokenType {
  LParen
  RParen
  UnOp(UnOp)
  BinOp(BinOp)
  Atom(Atom)
  EOF
}

pub type UnOp {
  Not
}

pub type BinOp {
  Add
  Sub
  Mul
  Div
  EqEq
  Ne
  Lt
  // Lesser than
  Gt
  // Greater than
  Le
  // Lesser or equal to
  Ge
  // Greater or equal to
  And
  Or
}

pub type Atom {
  Int(String)
  Str(String)
  Bool(Bool)
}
