import ast
import compiler/arg
import error
import gleam/bytes_tree
import gleam/dict
import gleam/list
import gleam/result
import span
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
    vars: dict.Dict(String, Int),
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
      vars: dict.new(),
      module:,
    )
    |> get_atom_id(module)
  compiler
}

pub fn compile_exprs(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use #(compiler, rest) <- result.try(compile_expr(compiler, exprs))
  case list.length(rest) {
    0 -> Ok(compiler)
    _ -> compile_exprs(compiler, rest)
  }
}

fn compile_expr(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> Result(#(Compiler, List(ast.Expr)), error.Error) {
  case exprs {
    [] -> Ok(#(compiler, []))
    [#(ast.Int(contents), _), ..rest] ->
      Ok(#(compile_int(compiler, contents), rest))
    [#(ast.Ident(name), span), ..rest] -> {
      use compiler <- result.try(compile_var(compiler, name, span))
      Ok(#(compiler, rest))
    }
    [#(ast.Sexpr(list), span), ..rest] -> {
      use compiler <- result.try(compile_sexpr(compiler, list, span))
      Ok(#(compiler, rest))
    }
    _ -> {
      let assert Ok(#(expr_type, span)) = list.first(exprs)
      Error(error.Error(error.UnexpectedExpr(expr_type), span:))
    }
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

/// Compiles a variable used in function body to beam instructions
/// Will output: {move,{x,name-index},{x,stack_size}}
fn compile_var(
  compiler: Compiler,
  name: String,
  span: span.Span,
) -> Result(Compiler, error.Error) {
  case compiler.vars |> dict.get(name) {
    Ok(index) -> {
      Ok(
        Compiler(
          ..add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
          |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(index))
          |> add_arg(
            arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size),
          ),
          stack_size: compiler.stack_size + 1,
        ),
      )
    }
    Error(_) -> Error(error.Error(error.NotFound(name), span))
  }
}

fn compile_sexpr(
  compiler: Compiler,
  list: List(ast.Expr),
  span: span.Span,
) -> Result(Compiler, error.Error) {
  case list {
    [#(ast.Sexpr(list), _), ..rest] -> {
      use compiler <- result.try(compile_sexpr(compiler, list, span))
      compiler |> compile_exprs(rest)
    }
    [#(ast.Ident(name), _), ..params] ->
      compile_call_expr(compiler, name, params)
    [#(ast.KeyWord(token.Cons), _), head, tail] ->
      compile_cons_expr(compiler, head, tail)
    [#(ast.KeyWord(token.List), _), ..exprs] -> compile_list(compiler, exprs)
    [#(ast.KeyWord(token.Var), _), #(ast.Ident(name), _), expr] ->
      compile_var_def_expr(compiler, name, expr)
    [
      #(ast.KeyWord(token.Use), _),
      #(ast.Str(module), _),
      #(ast.Str(name), _),
      #(ast.Int(arity), _),
    ] -> Ok(compile_use_expr(compiler, module, name, arity))
    [#(ast.KeyWord(token.Return), _), ..rest] ->
      compile_return_expr(compiler, rest)
    [#(ast.Op(operator), _), ..rest] ->
      compile_arth_expr(compiler, operator, rest)
    [
      #(ast.KeyWord(token.Func), _),
      #(ast.Ident(name), _),
      #(ast.Params(params), _),
      #(ast.Type(_ret_type), _),
      #(ast.Sexpr(body), _),
    ] -> compile_func_expr(compiler, name, params, body)
    _ ->
      Error(error.Error(
        error.UnexpectedList(
          list
          |> list.map(fn(x) { x.0 }),
        ),
        span,
      ))
  }
}

/// Compiles internally defined function calls to beam instructions
/// Will output: (for a func w/ a arity of 1)
/// {allocate,1,stack_size}
/// {move,{x,0},{y,0}}
/// {move,{x,stack_size-1},{x,0}}
/// {call,arity,{f,label}}
/// {move,{x,0},{x,stack_size}}
/// {move,{y,0},{x,0}}
/// {deallocate,1}
fn compile_call_expr(
  compiler: Compiler,
  name: String,
  params: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, params))
  let #(compiler, atom_id) = get_atom_id(compiler, name)
  let assert Ok(CompiledFunc(label, arity)) =
    dict.get(compiler.exports, atom_id)
  let assert True = arity == list.length(params)
  let compiler =
    add_arg(compiler, arg.new() |> arg.add_opc(arg.Allocate))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(1))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(compiler.stack_size),
    )
  let compiler =
    list.range(0, arity - 1)
    |> list.fold(compiler, fn(compiler, i) {
      add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
      |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(i))
      |> add_arg(arg.new() |> arg.add_tag(arg.Y) |> arg.int_opc(i))
      |> add_arg(arg.new() |> arg.add_opc(arg.Move))
      |> add_arg(
        arg.new()
        |> arg.add_tag(arg.X)
        |> arg.int_opc(compiler.stack_size - i - 1),
      )
      |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(i))
    })
    |> add_arg(arg.new() |> arg.add_opc(arg.Call))
    |> add_arg(arg.new() |> arg.int_tag(arity))
    |> add_arg(arg.new() |> arg.add_tag(arg.F) |> arg.int_opc(label))
    |> add_arg(arg.new() |> arg.add_opc(arg.Move))
    |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(0))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size),
    )
  let compiler =
    list.range(0, arity - 1)
    |> list.fold(compiler, fn(compiler, i) {
      add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
      |> add_arg(arg.new() |> arg.add_tag(arg.Y) |> arg.int_opc(i))
      |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(i))
    })
    |> add_arg(arg.new() |> arg.add_opc(arg.Deallocate))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(1))
  Ok(Compiler(..compiler, stack_size: compiler.stack_size + 1))
}

/// Compiles cons expressions to beam instructions
fn compile_cons_expr(
  compiler: Compiler,
  head: ast.Expr,
  tail: ast.Expr,
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, [head, tail]))
  Ok(compile_put_list(compiler))
}

/// Compiles list expression to beam instruction
/// (list 1 2 3) expression is equivalent of (cons 1 (cons 2 3)) expression
fn compile_list(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(
    exprs
    |> list.fold(Ok(compiler), fn(compiler, expr) {
      use compiler <- result.try(compiler)
      use #(compiler, _) <- result.try(compile_expr(compiler, [expr]))
      Ok(compiler)
    }),
  )
  Ok(
    list.fold(list.range(1, list.length(exprs) - 1), compiler, fn(compiler, _) {
      compile_put_list(compiler)
    }),
  )
}

/// Uses a put_list beam instruction between the two latest registers defined
/// Will output: {put_list,{x,stack_size-2},{x,stack_size-1}{x,stack_size-2}}
fn compile_put_list(compiler: Compiler) -> Compiler {
  Compiler(
    ..add_arg(compiler, arg.new() |> arg.add_opc(arg.PutList))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size - 2),
    )
    |> add_arg(
      arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size - 1),
    )
    |> add_arg(
      arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size - 2),
    ),
    stack_size: compiler.stack_size - 1,
  )
}

/// Compiles variable definition expressions
fn compile_var_def_expr(
  compiler: Compiler,
  name: String,
  expr: ast.Expr,
) -> Result(Compiler, error.Error) {
  use #(compiler, _) <- result.try(compile_expr(compiler, [expr]))
  Ok(
    Compiler(
      ..compiler,
      vars: compiler.vars |> dict.insert(name, compiler.stack_size - 1),
    ),
  )
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
fn compile_return_expr(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, exprs))
  Ok(
    add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 1),
    )
    |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(0))
    |> add_arg(arg.new() |> arg.add_opc(arg.Return)),
  )
}

/// Compiles arithmetic expressions to beam instructions
/// Will output: {gc_bif,operator,{f,0},2,[{x,stack_size},{x,stack_size+1},{x,stack_size}]}
/// ### Safety
/// Can only handle two operands for now due to restrictions of the GcBif2 instruction
fn compile_arth_expr(
  compiler: Compiler,
  operator: token.Op,
  operands: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  let assert 2 = list.length(operands)
  use compiler <- result.try(compile_exprs(compiler, operands))
  let compiler =
    compiler
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
  Ok(Compiler(..compiler, stack_size: compiler.stack_size - 1))
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
) -> Result(Compiler, error.Error) {
  let #(compiler, module_id) = compiler |> get_atom_id(compiler.module)
  let #(compiler, name_id) = compiler |> get_atom_id(name)
  let vars =
    params
    |> dict.to_list()
    |> list.map(fn(x) {
      let assert #(#(ast.Ident(name), _), #(_, index)) = x
      #(name, index)
    })
    |> dict.from_list()
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
    vars:,
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
