pub type Token {
  LParen
  RParen
  Op(Op)
  Int(Int)
  Str(String)
  Bool(Bool)
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

pub type KeyWord {
  Use
}
