pub type TokenType {
  LParen
  RParen
  Op(Op)
  Atom(Atom)
  EOF
}

// TODO: handle differently in the future?
pub type Op {
  /// +
  Add
  /// -
  Sub
  /// *
  Mul
  /// /
  Div
  /// ==
  EqEq
  /// !=
  Ne
  /// <
  Lt
  /// >
  Gt
  /// <=
  Le
  /// >=
  Ge
  /// and
  And
  /// or
  Or
  /// !
  Not
}

pub type Atom {
  Int(String)
  Str(String)
  Bool(Bool)
}
