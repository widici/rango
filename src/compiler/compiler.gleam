import ast
import compiler/arg
import gleam/bytes_tree
import gleam/dict
import gleam/list
import token

/// Used for representing foreign Erlang functions
/// In MFA-notation it whould be: module/name:arity
pub type ForeignFunc {
  ForeignFunc(module: String, name: String, arity: Int)
}

/// Maps function signature of foreign function to its corresponding id
pub type Imports =
  dict.Dict(#(Int, Int, Int), Int)

/// Maps an atom represented by a string to its corresponding id
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

fn append_arg(compiler: Compiler, arg: arg.Arg) -> Compiler {
  Compiler(
    ..compiler,
    data: bytes_tree.append(compiler.data, arg |> arg.encode_arg()),
  )
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
fn compile_int(compiler: Compiler, data: Int) -> Compiler {
  append_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
  |> append_arg(arg.new() |> arg.add_tag(arg.I) |> arg.int_opc(data))
  |> append_arg(
    arg.new()
    |> arg.add_tag(arg.X)
    |> arg.int_opc(compiler.stack_size),
  )
}

fn compile_list(compiler: Compiler, list: List(ast.Expr)) {
  case list {
    [first, ..rest] -> {
      case first {
        ast.Op(operator) -> compile_arth_expr(compiler, operator, rest)
        ast.KeyWord(keyword) ->
          case keyword {
            token.Use -> compile_use_expr(compiler, rest)
          }
        _ -> panic
      }
    }
    [] -> panic
  }
}

fn compile_use_expr(compiler: Compiler, operands: List(ast.Expr)) -> Compiler {
  let assert 3 = list.length(operands)
  let assert [ast.Str(module), ast.Str(name), ast.Int(arity)] = operands
  insert_func_id(compiler, ForeignFunc(module, name, arity))
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
    |> append_arg(arg.new() |> arg.add_opc(arg.GcBif2))
    // A fail will throw an exception on error due to flag being 0
    |> append_arg(arg.new() |> arg.add_tag(arg.F) |> arg.int_opc(0))
    |> append_arg(
      arg.new()
      |> arg.add_tag(arg.U)
      |> arg.int_opc(2),
    )

  let assert #(compiler, Ok(id)) =
    resolve_func_id(
      compiler,
      ForeignFunc(
        module: "erlang",
        name: case operator {
          token.Add -> "+"
          token.Sub -> "-"
          token.Mul -> "*"
          // token.Div is not handled in the same way with gc_bif2 and thus isn't pattern-matched
          _ -> panic
        },
        arity: 2,
      ),
    )

  let compiler =
    append_arg(compiler, arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(id))
    |> append_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 2),
    )
    |> append_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 1),
    )
    |> append_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 2),
    )
  Compiler(..compiler, stack_size: compiler.stack_size - 2)
}

fn get_atom_id(compiler: Compiler, name: String) -> #(Compiler, Int) {
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

fn resolve_func_sig(
  compiler: Compiler,
  func: ForeignFunc,
) -> #(Compiler, #(Int, Int, Int)) {
  let #(compiler, module_id) = get_atom_id(compiler, func.module)
  let #(compiler, func_id) = get_atom_id(compiler, func.name)
  #(compiler, #(module_id, func_id, func.arity))
}

fn resolve_func_id(
  compiler: Compiler,
  func: ForeignFunc,
) -> #(Compiler, Result(Int, Nil)) {
  let #(compiler, signature) = resolve_func_sig(compiler, func)
  #(compiler, signature |> dict.get(compiler.imports, _))
}

fn insert_func_id(compiler: Compiler, func: ForeignFunc) -> Compiler {
  let #(compiler, signature) = resolve_func_sig(compiler, func)
  let assert False = dict.has_key(compiler.imports, signature)
  Compiler(
    ..compiler,
    imports: dict.insert(
      compiler.imports,
      signature,
      compiler.imports |> dict.size(),
    ),
  )
}
