import ast
import compiler/arg
import gleam/bytes_tree
import gleam/dict
import gleam/int
import gleam/list
import token

pub type Imports =
  dict.Dict(#(Int, Int, Int), Int)

/// Maps an atom represented by a string based on it's corresponding id
/// Using a Dict here instead of a List should provide a better time-compexity in Gleam
pub type Atoms =
  dict.Dict(String, Int)

pub type Compiler {
  Compiler(
    stack_size: Int,
    data: bytes_tree.BytesTree,
    atoms: Atoms,
    imports: Imports,
  )
}

pub fn new() -> Compiler {
  Compiler(
    stack_size: 1,
    data: bytes_tree.new(),
    atoms: dict.new(),
    imports: dict.new(),
  )
}

fn append_arg(compiler: Compiler, bits: BitArray) -> Compiler {
  Compiler(..compiler, data: bytes_tree.append(compiler.data, bits))
}

pub fn compile_exprs(compiler: Compiler, exprs: List(ast.Expr)) -> Compiler {
  case exprs {
    [first, ..rest] -> {
      let compiler = case first {
        ast.Int(data) -> compile_int(compiler, data)
        ast.List(list) -> compile_list(compiler, list)
        _ -> panic
      }
      Compiler(..compiler, stack_size: compiler.stack_size + 1)
      |> compile_exprs(rest)
    }
    [] -> compiler
  }
}

/// Compiles an integer expression to beam instructions
/// Will output: {move,{integer,data},{x,stack_size}}
fn compile_int(compiler: Compiler, data: String) -> Compiler {
  let assert Ok(data) = int.parse(data)
  append_arg(compiler, <<arg.int_opc(arg.Move)>>)
  |> append_arg(arg.encode_arg(arg.int_tag(arg.I), data))
  |> append_arg(arg.encode_arg(arg.int_tag(arg.X), compiler.stack_size))
}

fn compile_list(compiler: Compiler, list: List(ast.Expr)) {
  case list {
    [first, ..rest] -> {
      case first {
        ast.Op(operator) -> compile_arth_expr(compiler, operator, rest)
        _ -> panic
      }
    }
    [] -> panic
  }
}

/// Compiles arithmetic expressions to beam instructions
/// Will output: {gc_bif,'operator',{f,0},2,[{x,stack_size},{x,stack_size+1},{x,stack_size}]}
/// ### Safety
/// Can only handle two operands for now due to restrictions of the GcBif2 instruction
fn compile_arth_expr(
  compiler: Compiler,
  operator: token.Op,
  operands: List(ast.Expr),
) -> Compiler {
  let assert 2 = list.length(operands)
  let compiler =
    compile_exprs(compiler, operands)
    |> append_arg(<<arg.int_opc(arg.GcBif2)>>)
    // A fail will throw an exception on error due to flag being 0
    |> append_arg(arg.encode_arg(arg.int_tag(arg.F), 0))
    |> append_arg(arg.encode_arg(arg.int_tag(arg.U), 2))

  let #(compiler, id) = case
    resolve_func_id(
      compiler,
      case operator {
        token.Add -> "+"
        token.Sub -> "-"
        token.Mul -> "*"
        // token.Div is not handled in the same way with gc_bif2 and thus isn't pattern-matched
        _ -> panic
      },
      "erlang",
      2,
    )
  {
    #(compiler, Ok(id)) -> #(compiler, id)
    _ -> panic
  }

  let compiler =
    append_arg(compiler, arg.encode_arg(arg.int_tag(arg.U), id))
    |> append_arg(arg.encode_arg(arg.int_tag(arg.X), compiler.stack_size - 2))
    |> append_arg(arg.encode_arg(arg.int_tag(arg.X), compiler.stack_size - 1))
    |> append_arg(arg.encode_arg(arg.int_tag(arg.X), compiler.stack_size - 2))
  Compiler(..compiler, stack_size: compiler.stack_size - 2)
}

pub fn get_atom_id(compiler: Compiler, name: String) -> #(Compiler, Int) {
  case dict.has_key(compiler.atoms, name) {
    True -> {
      let assert Ok(res) = dict.get(compiler.atoms, name)
      #(compiler, res)
    }
    False ->
      Compiler(
        ..compiler,
        atoms: dict.insert(compiler.atoms, name, dict.size(compiler.atoms)),
      )
      |> get_atom_id(name)
  }
}

pub fn resolve_func_id(
  compiler: Compiler,
  module: String,
  func: String,
  arity: Int,
) -> #(Compiler, Result(Int, Nil)) {
  let #(compiler, module_id) = get_atom_id(compiler, module)
  let #(compiler, func_id) = get_atom_id(compiler, func)
  #(compiler, #(module_id, func_id, arity) |> dict.get(compiler.imports, _))
}
