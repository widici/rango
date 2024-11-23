import ast
import gleam/bytes_tree
import gleam/int

pub opaque type Compiler {
  Compiler(stack_size: Int, data: bytes_tree.BytesTree)
}

pub fn new() -> Compiler {
  Compiler(stack_size: 1, data: bytes_tree.new())
}

pub type OpCode {
  Label
  Move
  GcBif2
}

/// Returns the corresponding Int used to represent the bytecode for a given OpCode
pub fn int(opcode: OpCode) -> Int {
  case opcode {
    Label -> 1
    Move -> 64
    GcBif2 -> 125
  }
}

pub type Tag {
  I
  X
  F
}

pub fn encode_arg(tag: Tag, opcode: Int) -> BitArray {
  let tag = case tag {
    I -> 1
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

fn append_arg(bits: BitArray, compiler: Compiler) -> Compiler {
  Compiler(..compiler, data: bytes_tree.append(compiler.data, bits))
}

fn compile_expr(compiler: Compiler, exprs: List(ast.Expr)) -> Compiler {
  case exprs {
    [first, ..rest] -> {
      case first {
        ast.Int(x) -> {
          append_arg(<<int(Move)>>, compiler)
          let assert Ok(x) = int.parse(x)
          encode_arg(I, x) |> append_arg(compiler)
          encode_arg(X, compiler.stack_size) |> append_arg(compiler)
        }
        _ -> panic
      }
      compile_expr(compiler, rest)
    }
    [] -> compiler
  }
}
