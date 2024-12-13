import ast
import compiler/arg
import gleam/bytes_tree
import gleam/int

pub opaque type Compiler {
  Compiler(stack_size: Int, data: bytes_tree.BytesTree)
}

pub fn new() -> Compiler {
  Compiler(stack_size: 1, data: bytes_tree.new())
}

fn append_arg(bits: BitArray, compiler: Compiler) -> Compiler {
  Compiler(..compiler, data: bytes_tree.append(compiler.data, bits))
}

fn compile_expr(compiler: Compiler, exprs: List(ast.Expr)) -> Compiler {
  case exprs {
    [first, ..rest] -> {
      case first {
        ast.Int(x) -> {
          append_arg(<<arg.int_opc(arg.Move)>>, compiler)
          let assert Ok(x) = int.parse(x)
          arg.encode_arg(arg.int_tag(arg.I), x) |> append_arg(compiler)
          arg.encode_arg(arg.int_tag(arg.X), compiler.stack_size)
          |> append_arg(compiler)
        }
        _ -> panic
      }
      Compiler(..compiler, stack_size: compiler.stack_size + 1)
      |> compile_expr(rest)
    }
    [] -> compiler
  }
}
