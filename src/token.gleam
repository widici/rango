import span

pub type Token =
  #(TokenType, span.Span)

pub type TokenType {
  /// (
  LParen
  /// )
  RParen
  /// [
  LSquare
  /// ]
  RSquare
  Ident(String)
  Type(Type)
  Op(Op)
  Int(Int)
  Str(String)
  Bool(Bool)
  Nil
  Ok
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
  /// <>
  Concat
}

pub type KeyWord {
  /// use
  Use
  /// fn
  Func
  /// ret
  Return
  /// var
  Var
  /// list
  List
  /// cons
  Cons
}

pub type Type {
  /// Int
  IntType
  /// Str
  StrType
  /// Bool
  BoolType
}
