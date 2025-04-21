import ast
import compiler/arg
import error
import gleam/bytes_tree
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import span
import token

/// Used for representing foreign Erlang functions
/// In MFA-notation it whould be: module/name:arity
pub type ForeignFunc {
  ForeignFunc(module: String, name: String, arity: Int)
}

/// Maps function signature of foreign function to its index
pub type Imports =
  dict.Dict(#(Int, Int, Int), Int)

/// Maps the id and arity of a compiled function to its label
pub type Exports =
  dict.Dict(#(Int, Int), Int)

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
    labels: List(#(Int, bytes_tree.BytesTree)),
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
      labels: [],
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
    [#(ast.Str(contents), _), ..rest] ->
      Ok(#(compile_str(compiler, contents), rest))
    [#(ast.Nil, _), ..rest] -> Ok(#(compile_nil(compiler), rest))
    [#(ast.Ok, _), ..rest] -> Ok(#(compile_ok(compiler), rest))
    [#(ast.Bool(bool), _), ..rest] -> Ok(#(compile_bool(compiler, bool), rest))
    [
      #(
        ast.Sexpr([
          #(ast.KeyWord(token.If), _),
          conditional,
          #(ast.Sexpr(body), _),
        ]),
        _,
      ),
      ..rest
    ] -> {
      // ast.KeyWord(token.If), _), conditional, #(ast.Sexpr(body), _
      use compiler <- result.try(compile_if_expr(
        compiler,
        conditional,
        body,
        rest,
      ))
      Ok(#(compiler, []))
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

/// Compiles strings to beam instructions
/// ### Important
/// Compiles to charlists not to binaries
fn compile_str(compiler: Compiler, str: String) -> Compiler {
  string.to_utf_codepoints(str)
  |> list.map(string.utf_codepoint_to_int)
  |> list.fold(compiler, fn(compiler, code_point) {
    compile_int(compiler, code_point)
  })
  |> compile_list(string.length(str))
}

/// Will output: {move,{atom,id},{x,stack_size}}
fn compile_atom(compiler: Compiler, id: Int) -> Compiler {
  Compiler(
    ..add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
    |> add_arg(arg.new() |> arg.add_tag(arg.A) |> arg.int_opc(id))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size),
    ),
    stack_size: compiler.stack_size + 1,
  )
}

/// Will output: {move,{atom,0},{x,stack_size}}
fn compile_nil(compiler: Compiler) -> Compiler {
  compile_atom(compiler, 0)
}

fn compile_ok(compiler: Compiler) -> Compiler {
  let #(compiler, atom_id) = get_atom_id(compiler, "ok")
  compile_atom(compiler, atom_id)
}

fn compile_bool(compiler: Compiler, bool: Bool) -> Compiler {
  let name = case bool {
    True -> "true"
    False -> "false"
  }
  let #(compiler, atom_id) = get_atom_id(compiler, name)
  compile_atom(compiler, atom_id)
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
      compile_call_expr(compiler, name, params, span)
    [#(ast.KeyWord(token.Cons), _), head, tail] ->
      compile_cons_expr(compiler, head, tail)
    [#(ast.KeyWord(token.List), _), ..exprs] ->
      compile_list_expr(compiler, exprs)
    [#(ast.KeyWord(token.Var), _), #(ast.Ident(name), _), expr] ->
      compile_var_def_expr(compiler, name, expr)
    [
      #(ast.KeyWord(token.Use), _),
      #(ast.Str(module), _),
      #(ast.Str(name), _),
      #(ast.Int(arity), _),
    ] -> compile_use_expr(compiler, module, name, arity, span)
    [#(ast.KeyWord(token.Return), _), ..rest] ->
      compile_return_expr(compiler, rest)
    [#(ast.Op(operator), _), ..rest] ->
      case operator {
        token.Add | token.Sub | token.Mul ->
          compile_arth_expr(compiler, operator, rest, span)
        token.Concat -> compile_concat_expr(compiler, rest, span)
        token.EqEq
        | token.Ne
        | token.Lt
        | token.Gt
        | token.Le
        | token.Ge
        | token.And
        | token.Or -> compile_conditional(compiler, operator, rest, span)
        _ -> panic
      }
    //[#(ast.KeyWord(token.If), _), conditional, #(ast.Sexpr(body), _)] -> {
    //  io.debug(list)
    //  compile_if_expr(compiler, conditional, body, rest)
    //}
    [
      #(ast.KeyWord(token.Func), _),
      #(ast.Ident(name), _),
      #(ast.Params(params), _),
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
/// (list 1 2 3) expression is equivalent of a (cons 1 (cons 2 (cons 3 Nil))) expression
/// ### Important
/// Compiles to proper lists not improper lists
fn compile_list_expr(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, exprs))
  Ok(compile_list(compiler, list.length(exprs)))
}

/// ### Important
/// Compiles to proper lists not improper lists
fn compile_list(compiler: Compiler, times: Int) -> Compiler {
  compile_nil(compiler) |> make_variadic(compile_put_list, times)
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

/// Inserts foreign function to imports
fn compile_use_expr(
  compiler: Compiler,
  module: String,
  name: String,
  arity: Int,
  span: span.Span,
) -> Result(Compiler, error.Error) {
  add_func_id(compiler, ForeignFunc(module, name, arity), span)
}

/// Returns evaluation of exprs from function
fn compile_return_expr(
  compiler: Compiler,
  exprs: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, exprs))
  Ok(compile_return(compiler))
}

/// Will output:
/// {move,{x,stack_size-1},{x,0}}
/// {return}
fn compile_return(compiler: Compiler) -> Compiler {
  add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
  |> add_arg(
    arg.new()
    |> arg.add_tag(arg.X)
    |> arg.int_opc(compiler.stack_size - 1),
  )
  |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(0))
  |> add_arg(arg.new() |> arg.add_opc(arg.Return))
}

fn compile_call_expr(
  compiler: Compiler,
  name: String,
  params: List(ast.Expr),
  span: span.Span,
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, params))
  let #(compiler, name_id) = get_atom_id(compiler, name)
  let arity = list.length(params)
  let external =
    dict.filter(compiler.imports, fn(key, _) {
      key.1 == name_id && key.2 == arity
    })
    |> dict.values()
  use _ <- result.try(case list.length(external) {
    x if x > 1 -> Error(error.Error(error.AmbigousCall(name, arity), span))
    _ -> Ok(Nil)
  })
  let external = list.first(external)
  let local = dict.get(compiler.exports, #(name_id, arity))
  case external, local {
    Error(_), Ok(label) -> Ok(compile_local_call(compiler, arity, label))
    Ok(index), Error(_) -> Ok(compile_external_call(compiler, arity, index))
    Ok(_), Ok(_) -> Error(error.Error(error.AmbigousCall(name, arity), span))
    Error(_), Error(_) ->
      Error(error.Error(error.MissingFunc(name, arity), span))
  }
}

fn compile_local_call(compiler: Compiler, arity: Int, label: Int) -> Compiler {
  io.debug(compiler.stack_size)
  compile_call(compiler, arity, fn(compiler) {
    add_arg(compiler, arg.new() |> arg.add_opc(arg.Call))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(arity))
    |> add_arg(arg.new() |> arg.add_tag(arg.F) |> arg.int_opc(label))
  })
}

fn compile_external_call(compiler: Compiler, arity: Int, index: Int) -> Compiler {
  compile_call(compiler, arity, fn(compiler) {
    add_arg(compiler, arg.new() |> arg.add_opc(arg.CallExt))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(arity))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(index))
  })
}

/// Compiles function call to beam instructions
/// Will output: (for a func w/ a arity of 1)
/// {allocate,1,stack_size}
/// {move,{x,0},{y,0}}
/// {move,{x,stack_size-1},{x,0}}
/// func()
/// {move,{x,0},{x,stack_size}}
/// {move,{y,0},{x,0}}
/// {deallocate,1}
fn compile_call(
  compiler: Compiler,
  arity: Int,
  func: fn(Compiler) -> Compiler,
) -> Compiler {
  let range = list.range(0, int.max(arity - 1, 0))
  let compiler =
    add_arg(compiler, arg.new() |> arg.add_opc(arg.Allocate))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(arity))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(compiler.stack_size),
    )
  let compiler =
    range
    |> list.fold(compiler, fn(compiler, i) {
      add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
      |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(i))
      |> add_arg(arg.new() |> arg.add_tag(arg.Y) |> arg.int_opc(i))
      |> add_arg(arg.new() |> arg.add_opc(arg.Move))
      |> add_arg(
        arg.new()
        |> arg.add_tag(arg.X)
        |> arg.int_opc(compiler.stack_size - arity + i),
      )
      |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(i))
    })
    |> func()
    |> add_arg(arg.new() |> arg.add_opc(arg.Move))
    |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(0))
    |> add_arg(
      arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(compiler.stack_size),
    )
  let compiler =
    range
    |> list.fold(compiler, fn(compiler, i) {
      add_arg(compiler, arg.new() |> arg.add_opc(arg.Move))
      |> add_arg(arg.new() |> arg.add_tag(arg.Y) |> arg.int_opc(i))
      |> add_arg(arg.new() |> arg.add_tag(arg.X) |> arg.int_opc(i))
    })
    |> add_arg(arg.new() |> arg.add_opc(arg.Deallocate))
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(arity))
  Compiler(..compiler, stack_size: compiler.stack_size + 1)
}

fn compile_concat_expr(
  compiler: Compiler,
  operands: List(ast.Expr),
  span: span.Span,
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, operands))
  use #(compiler, index) <- result.try(resolve_func_id(
    compiler,
    ForeignFunc("lists", "flatten", 1),
    span,
  ))
  Ok(
    compile_list(compiler, list.length(operands))
    |> compile_external_call(1, index),
  )
}

/// Compiles arithmetic expressions to beam instructions
fn compile_arth_expr(
  compiler: Compiler,
  operator: token.Op,
  operands: List(ast.Expr),
  span: span.Span,
) -> Result(Compiler, error.Error) {
  use compiler <- result.try(compile_exprs(compiler, operands |> list.reverse()))
  let name = case operator {
    token.Add -> "+"
    token.Sub -> "-"
    token.Mul -> "*"
    // token.Div is not handled in the same way with gc_bif2 and thus isn't pattern-matched
    _ -> panic
  }
  use #(compiler, bif) <- result.try(resolve_func_id(
    compiler,
    ForeignFunc("erlang", name, 2),
    span,
  ))
  Ok(make_variadic(
    compiler,
    fn(x) { compile_bif2(x, bif) },
    list.length(operands) - 1,
  ))
}

fn compile_conditional(
  compiler: Compiler,
  operator: token.Op,
  exprs: List(ast.Expr),
  span: span.Span,
) -> Result(Compiler, error.Error) {
  let assert [lhs, rhs] = exprs
  // Compiled in reverse order due to compile_bif2 implementation
  let exprs = case operator {
    token.Gt | token.Le -> [lhs, rhs]
    _ -> [rhs, lhs]
  }
  use compiler <- result.try(compile_exprs(compiler, exprs))
  let name = case operator {
    token.EqEq -> "=:="
    token.Ne -> "=/="
    token.Lt | token.Gt -> "<"
    token.Le | token.Ge -> ">="
    token.And -> "and"
    token.Or -> "or"
    _ -> panic
  }
  use #(compiler, bif) <- result.try(resolve_func_id(
    compiler,
    ForeignFunc("erlang", name, 2),
    span,
  ))
  Ok(compile_bif2(compiler, bif))
}

/// Will output: {gc_bif,bif,{f,0},2,[{x,stack_size},{x,stack_size+1},{x,stack_size}]}
/// ### Important
/// Applies the bif in reverse so that stack_size+1 is the first param & stack_size the second one
/// Therefore params needs to be compiled in reverse order
fn compile_bif2(compiler: Compiler, bif: Int) -> Compiler {
  Compiler(
    // A fail will throw an exception on error due to flag being 0
    ..add_arg(compiler, arg.new() |> arg.add_opc(arg.GcBif2))
    |> add_arg(arg.new() |> arg.add_tag(arg.F) |> arg.int_opc(0))
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.U)
      |> arg.int_opc(compiler.stack_size),
    )
    |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(bif))
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
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.X)
      |> arg.int_opc(compiler.stack_size - 2),
    ),
    stack_size: compiler.stack_size - 1,
  )
}

fn compile_if_expr(
  compiler: Compiler,
  conditional: ast.Expr,
  body: List(ast.Expr),
  rest: List(ast.Expr),
) -> Result(Compiler, error.Error) {
  use #(compiler, _) <- result.try(compile_expr(compiler, [conditional]))
  let compiler = compile_bool(compiler, True)
  let compiler =
    Compiler(
      ..add_arg(compiler, arg.new() |> arg.add_opc(arg.IsEqExact))
      |> add_arg(
        arg.new()
        |> arg.add_tag(arg.F)
        |> arg.int_opc(compiler.label_count + 1),
      )
      |> add_arg(
        arg.new()
        |> arg.add_tag(arg.X)
        |> arg.int_opc(compiler.stack_size - 2),
      )
      |> add_arg(
        arg.new()
        |> arg.add_tag(arg.X)
        |> arg.int_opc(compiler.stack_size - 1),
      ),
      label_count: compiler.label_count + 1,
    )
  use new_compiler <- result.try(
    Compiler(
      ..compiler,
      data: bytes_tree.new(),
      labels: [],
      label_count: compiler.label_count + 1,
    )
    |> compile_exprs(rest),
  )
  use compiler <- result.try(compile_exprs(compiler, body))
  let compiler =
    add_arg(compiler, arg.new() |> arg.add_opc(arg.Jump))
    |> add_arg(
      arg.new()
      |> arg.add_tag(arg.F)
      |> arg.int_opc(compiler.label_count),
    )
  Ok(
    Compiler(
      ..compiler,
      labels: list.append(compiler.labels, [
        #(compiler.label_count, new_compiler.data),
        ..new_compiler.labels
      ]),
    ),
  )
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
  let compiler =
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
        |> dict.insert(#(name_id, dict.size(params)), compiler.label_count + 2),
      vars:,
    )
  use compiler <- result.try(compile_exprs(compiler, body))
  Ok(
    list.fold(compiler.labels, compiler, fn(compiler, label) {
      let compiler =
        add_arg(compiler, arg.new() |> arg.add_opc(arg.Label))
        |> add_arg(arg.new() |> arg.add_tag(arg.U) |> arg.int_opc(label.0))
      Compiler(
        ..compiler,
        data: compiler.data |> bytes_tree.append_tree(label.1),
      )
    })
    |> compile_ok()
    |> compile_return(),
  )
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
  span: span.Span,
) -> Result(#(Compiler, Int), error.Error) {
  let #(compiler, signature) = resolve_func_sig(compiler, func)
  case dict.get(compiler.imports, signature) {
    Ok(signature) -> Ok(#(compiler, signature))
    Error(_) ->
      Error(error.Error(error.MissingFunc(func.name, func.arity), span))
  }
}

fn add_func_id(
  compiler: Compiler,
  func: ForeignFunc,
  span: span.Span,
) -> Result(Compiler, error.Error) {
  let #(compiler, signature) = resolve_func_sig(compiler, func)
  use _ <- result.try(case dict.has_key(compiler.imports, signature) {
    True ->
      Error(error.Error(
        error.RedundantImporting(func.module, func.name, func.arity),
        span,
      ))
    False -> Ok(Nil)
  })
  let #(compiler, name_id) = get_atom_id(compiler, func.name)
  use _ <- result.try(case
    dict.filter(compiler.imports, fn(key, _) {
      key.1 == name_id && key.2 == func.arity
    })
    |> dict.size()
  {
    x if x == 0 -> Ok(Nil)
    _ ->
      Error(error.Error(
        error.ImportConflict(func.module, func.name, func.arity),
        span,
      ))
  })
  Ok(
    Compiler(
      ..compiler,
      imports: dict.insert(
        compiler.imports,
        signature,
        compiler.imports |> dict.size(),
      ),
    ),
  )
}

/// Makes binary func accept times-amount of params instead of 2
/// E.g. Turns (+ 1 2 3 4) -> (+ 1 (+ 2 (+ 3 4)))
/// ### Important
/// Params needs to be compiled before calling the function
fn make_variadic(
  compiler: Compiler,
  func: fn(Compiler) -> Compiler,
  times: Int,
) -> Compiler {
  list.fold(list.range(1, times), compiler, fn(compiler, _) { func(compiler) })
}
