import argv
import compiler/chunk
import compiler/compiler
import error
import gleam
import gleam/bytes_tree
import gleam/dynamic
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import lexer
import parser
import simplifile

@external(erlang, "code", "add_path")
fn add_path(path: charlist.Charlist) -> Bool

type LoadResult {
  Module(atom.Atom)
}

@external(erlang, "code", "load_file")
fn load_file(file: atom.Atom) -> LoadResult

@external(erlang, "util", "to_term")
fn to_term(term: charlist.Charlist) -> dynamic.Dynamic

@external(erlang, "erlang", "apply")
fn apply(
  module: atom.Atom,
  name: atom.Atom,
  args: List(dynamic.Dynamic),
) -> dynamic.Dynamic

fn run() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles source-code into a beam binary and runs it",
  )
  use _, args, _ <- glint.command()
  let assert [path, function, ..rest] = args
  let assert gleam.Ok(file_name) =
    load_program(path)
    |> result.map_error(fn(e) { error.to_string(e) |> io.print_error() })
  let params =
    list.map(rest, fn(t) { { t <> "." } |> charlist.from_string() |> to_term() })
  apply(
    atom.create_from_string(file_name),
    atom.create_from_string(function),
    params,
  )
  |> io.debug()
  Nil
}

fn load() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles source-code into a beam binary and attempts loading the beam file, useful for quick debugging",
  )
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let _ =
    load_program(path)
    |> result.map_error(fn(e) { error.to_string(e) |> io.print_error() })
  Nil
}

fn load_program(path: String) -> Result(String, error.Error) {
  use file_name <- result.try(build_src(path))
  let assert True =
    charlist.from_string(".")
    |> add_path()
  let Module(_) = load_file(file_name |> atom.create_from_string())
  gleam.Ok(file_name)
}

fn build() -> glint.Command(Nil) {
  use <- glint.command_help("Compiles source-code into a beam binary")
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let _ =
    build_src(path)
    |> result.map_error(fn(e) { error.to_string(e) |> io.print_error() })
  Nil
}

fn build_src(path: String) -> Result(String, error.Error) {
  let assert [file_ident, ..] = string.split(path, "/") |> list.reverse()
  let assert [file_name, _] = string.split(file_ident, ".")
  let assert gleam.Ok(src) = simplifile.read(path)
  let assert gleam.Ok(prelude) = simplifile.read("./prelude/prelude.lisp")
  use prelude_tokens <- result.try(
    lexer.new(prelude, "./prelude/prelude.lisp")
    |> lexer.lex(),
  )
  use src_tokens <- result.try(lexer.new(src, path) |> lexer.lex())
  let tokens = prelude_tokens |> list.append(src_tokens)
  use ast <- result.try(tokens |> parser.parse())
  use compiler <- result.try(
    compiler.new(file_name) |> compiler.compile_exprs(ast),
  )
  let beam_module =
    chunk.compile_beam_module(compiler) |> bytes_tree.to_bit_array()
  let assert gleam.Ok(Nil) =
    simplifile.write_bits(file_name <> ".beam", beam_module)
  gleam.Ok(file_name)
}

pub fn main() {
  glint.new()
  |> glint.with_name("rango")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(["build"], build())
  |> glint.add(["load"], load())
  |> glint.add(["run"], run())
  |> glint.run(argv.load().arguments)
}
