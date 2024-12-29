import gleam/int

/// Represents OpCodes used for beam-vm bytecode
pub type OpCode {
  Label
  Move
  GcBif2
}

/// Returns the corresponding Int used to represent a given OpCode
pub fn int_opc(opcode: OpCode) -> Int {
  case opcode {
    Label -> 1
    Move -> 64
    GcBif2 -> 125
  }
}

/// Represents Tags used for beam-vm bytecode
pub type Tag {
  /// Unsigned
  U
  /// Integer
  I
  /// X register
  X
  /// Label
  F
}

/// Returns the corresponding Int used to represent a given Tag
pub fn int_tag(tag: Tag) -> Int {
  case tag {
    U -> 0
    I -> 1
    X -> 3
    F -> 5
  }
}

pub fn encode_arg(tag: Int, opcode: Int) -> BitArray {
  case opcode {
    n if n < 0 -> panic
    n if n < 16 -> <<{ int.bitwise_shift_left(n, 4) |> int.bitwise_or(tag) }>>
    n if n < 0x800 -> <<
      {
        int.bitwise_shift_right(n, 3)
        |> int.bitwise_and(0b11100000)
        |> int.bitwise_or(tag)
        |> int.bitwise_or(0b00001000)
      },
      { int.bitwise_and(n, 0xff) },
    >>
    _ -> panic
  }
}
