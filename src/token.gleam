pub type TokenType {
  LParen
  RParen
  Op(Op)
  Atom(Atom)
  KeyWord(KeyWord)
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
  Int(Int)
  Str(String)
  Bool(Bool)
}

pub type KeyWord {
  Use
}
