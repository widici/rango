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

/// Used for representing the metadata (label & arity) of native compiled functions
pub type CompiledFunc {
  CompiledFunc(label: Int, arity: Int)
}

/// Maps the id of a compiled function to its metadata
pub type Exports =
  dict.Dict(Int, CompiledFunc)

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
    exports: Exports,
    label_count: Int,
    params: dict.Dict(ast.Expr, #(token.Type, Int)),
    module: String,
  )
}

pub fn new(module: String) -> Compiler {
  let assert #(compiler, 1) =
    Compiler(
      stack_size: 1,
      data: bytes_tree.new(),
      atoms: dict.new(),
      imports: dict.new(),
      exports: dict.new(),
      label_count: 0,
      params: dict.new(),
      module:,
    )
    |> get_atom_id(module)
  compiler
}

pub fn compile_exprs(compiler: Compiler, exprs: List(ast.Expr)) -> Compiler {
  let #(compiler, rest) = compile_expr(compiler, exprs)
  case list.length(rest) {
    0 -> compiler
    _ -> compile_exprs(compiler, rest)
  }
}

fn compile_expr(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> #(Compiler, List(ast.Expr)) {
  case exprs {
    [] -> #(compiler, [])
    [ast.Int(contents), ..rest] -> #(compile_int(compiler, contents), rest)
    [ast.Ident(_), ..rest] -> {
      let assert Ok(ident) = list.first(exprs)
      #(compile_var(compiler, ident), rest)
    }
    [ast.List(list), ..rest] -> #(compile_list(compiler, list), rest)
    _ -> panic
  }
}

/// Compiles an integer expression to beam instructions
/// Will output: {move,{integer,contents},{x,stack_size}}
fn compile_int(compiler: Compiler, contents: Int) -> Compiler {
  Compiler(
    ..add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
    |> add_arg(arg.new() |> arg.add_tag(arg.I) |> arg.int_opc(contents))
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size),
    ),
    stack_size: compiler.stack_size + 1,
  )
}

/// Compiles a param used in function body to beam instructions
/// Will output: {move,{x,ident-index},{x,stack_size}}
fn compile_var(compiler: Compiler, ident: ast.Expr) -> Compiler {
  case compiler.params |> dict.get(ident) {
    Ok(#(_, index)) -> {
      Compiler(
        ..add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
        |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(index))
        |> add_arg(
          arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size),
        ),
        stack_size: compiler.stack_size + 1,
      )
    }
    // TODO: handle this as an error
    Error(_) -> panic
  }
}

fn compile_list(compiler: Compiler, list: List(ast.Expr)) -> Compiler {
  case list {
    [ast.List(list), ..rest] ->
      compile_list(compiler, list) |> compile_exprs(rest)
    [ast.Op(operator), ..rest] -> compile_arth_expr(compiler, operator, rest)
    [ast.KeyWord(token.Use), ast.Str(module), ast.Str(name), ast.Int(arity)] ->
      compile_use_expr(compiler, module, name, arity)
    [ast.KeyWord(token.Return), ..rest] -> compile_return_expr(compiler, rest)
    [
      ast.KeyWord(token.Func),
      ast.Ident(name),
      ast.Params(params),
      ast.Type(_ret_type),
      ast.List(body),
    ] -> compile_func_expr(compiler, name, params, body)
    _ -> panic
  }
}

/// Inserts foreign function's MFA to imports
fn compile_use_expr(
  compiler: Compiler,
  module: String,
  name: String,
  arity: Int,
) -> Compiler {
  add_func_id(compiler, ForeignFunc(module, name, arity))
}

/// Returns evaluation of exprs from function
/// Will output:
/// {move,{x,stack_size-1},{x,0}}
/// {return}
fn compile_return_expr(compiler: Compiler, exprs: List(ast.Expr)) -> Compiler {
  let compiler = compile_exprs(compiler, exprs)
  add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
  |> add_arg(
    arg.new()
    |> arg.add_tag(arg.X)
    |> arg.int_opc(compiler.stack_size - 1),
  )
  |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(0))
  |> add_arg(arg.new() |> arg.add_opc(arg.Return))
}

/// Compiles arithmetic expressions to beam instructions
/// Will output: {gc_bif,operator,{f,0},2,[{x,stack_size},{x,stack_size+1},{x,stack_size}]}
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
    |> add_arg(arg.new() |> arg.add_opc(arg.GcBif2))
    // A fail will throw an exception on error due to flag being 0
    |> add_arg(arg.new() |> arg.add_tag(arg.F) |> arg.int_opc(0))
    |> add_arg(
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
    add_arg(compiler, arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(id))
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 2),
    )
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 1),
    )
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 2),
    )
  Compiler(..compiler, stack_size: compiler.stack_size - 1)
}

/// Compiles a function defintion expression to beam instructions
/// Will output:
/// {function, func-id, params-len, label_count+2}.
///   {label,label_count+1}.
///     {func_info,{atom,module-id},{atom,name-id}}.
///   {label,label-count+2}.
///     body
///
fn compile_func_expr(
  compiler: Compiler,
  name: String,
  params: dict.Dict(ast.Expr, #(token.Type, Int)),
  body: List(ast.Expr),
) -> Compiler {
  let #(compiler, module_id) = compiler |> get_atom_id(compiler.module)
  let #(compiler, name_id) = compiler |> get_atom_id(name)

  Compiler(
    ..add_arg(compiler, arg.new() |> arg.add_opc(arg.Label))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(compiler.label_count + 1),
    )
    |> add_arg(arg.new() |> arg.add_opc(arg.FuncInfo))
    |> add_arg(arg.new() |> arg.add_tag(arg.A) |> arg.int_opc(module_id))
    |> add_arg(arg.new() |> arg.add_tag(arg.A) |> arg.int_opc(name_id))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(dict.size(params)),
    )
    |> add_arg(arg.new() |> arg.add_opc(arg.Label))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(compiler.label_count + 2),
    ),
    stack_size: dict.size(params),
    label_count: compiler.label_count + 2,
    exports: compiler.exports
      |> dict.insert(
        name_id,
        CompiledFunc(compiler.label_count + 2, dict.size(params)),
      ),
    params:,
  )
  // TODO: check if this is valid for multiple exprs in body
  |> compile_exprs(body)
}

pub fn add_arg(compiler: Compiler, arg: arg.Arg) -> Compiler {
  Compiler(
    ..compiler,
    data: bytes_tree.append(compiler.data, arg |> arg.encode_arg()),
  )
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
        atoms: dict.insert(compiler.atoms, name, dict.size(compiler.atoms) + 1),
      )
      |> get_atom_id(name)
  }
}

fn resolve_func_sig(
  compiler: Compiler,
  func: ForeignFunc,
) -> #(Compiler, #(Int, Int, Int)) {
  let #(compiler, module_id) = get_atom_id(compiler, func.module)
  let #(compiler, name_id) = get_atom_id(compiler, func.name)
  #(compiler, #(module_id, name_id, func.arity))
}

fn resolve_func_id(
  compiler: Compiler,
  func: ForeignFunc,
) -> #(Compiler, Result(Int, Nil)) {
  let #(compiler, signature) = resolve_func_sig(compiler, func)
  #(compiler, signature |> dict.get(compiler.imports, _))
}

fn add_func_id(compiler: Compiler, func: ForeignFunc) -> Compiler {
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
