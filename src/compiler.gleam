import gleam/bytes_tree
import gleam/int

pub opaque type Compiler {
  Compiler(stack_size: Int, data: bytes_tree.BytesTree)
}

pub fn new() -> Compiler {
  Compiler(stack_size: 0, data: bytes_tree.new())
}

pub type OpCode {
  Label
  Move
  GcBif2
}

pub type Tag {
  X
  F
}

pub fn encode_arg(opcode: OpCode, tag: Tag) -> BitArray {
  let opcode = case opcode {
    Label -> 1
    Move -> 64
    GcBif2 -> 125
  }
  let tag = case tag {
    X -> 3
    F -> 5
  }
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
