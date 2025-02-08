// TODO: see if everything is necesary, clean up boilerplate, etc.
import gleam/int
import gleam/option

pub opaque type Arg {
  Arg(tag: option.Option(Int), opcode: option.Option(Int))
}

/// Represents OpCodes used for beam-vm bytecode
pub type OpCode {
  Label
  Move
  GcBif2
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

pub fn new() -> Arg {
  Arg(tag: option.None, opcode: option.None)
}

/// Changes tag in arg to the Int that is used to identify it
pub fn add_tag(arg: Arg, tag: Tag) -> Arg {
  Arg(
    ..arg,
    tag: option.Some(case tag {
      U -> 0
      I -> 1
      X -> 3
      F -> 5
    }),
  )
}

// Changes opcode in arg to the Int that is used to identify it
pub fn add_opc(arg: Arg, opcode: OpCode) -> Arg {
  Arg(
    ..arg,
    opcode: option.Some(case opcode {
      Label -> 1
      Move -> 64
      GcBif2 -> 125
    }),
  )
}

/// Changes tag in arg to specified Int
pub fn int_tag(arg: Arg, tag: Int) -> Arg {
  Arg(..arg, tag: option.Some(tag))
}

/// Changes opcode in tag to specified Int
pub fn int_opc(arg: Arg, opcode: Int) -> Arg {
  Arg(..arg, opcode: option.Some(opcode))
}

pub fn encode_arg(arg: Arg) -> BitArray {
  case arg.tag, arg.opcode {
    option.Some(tag), option.Some(opcode) -> compact_term_encode(tag, opcode)
    option.Some(tag), option.None -> <<tag>>
    option.None, option.Some(opcode) -> <<opcode>>
    option.None, option.None -> panic
  }
}

fn compact_term_encode(tag: Int, opcode: Int) -> BitArray {
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
