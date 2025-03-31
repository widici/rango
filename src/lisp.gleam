import argv
import compiler/chunk
import compiler/compiler
import gleam/bytes_tree
import gleam/erlang/atom
import gleam/erlang/charlist
import gleam/io
import gleam/list
import gleam/string
import glint
import lexer
import parser
import simplifile

@external(erlang, "code", "add_path")
fn add_path(path: charlist.Charlist) -> Nil

@external(erlang, "code", "load_file")
fn load_file(file: atom.Atom) -> Nil

fn run() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles the source-code into a beam instruction bytecode binary and run it",
  )
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let assert [file_ident, ..dir_path] =
    string.split(path, "/") |> list.reverse()
  let assert [filename, _] = string.split(file_ident, ".") |> list.reverse()
  build_src(path, filename)
  add_path(list.reverse(dir_path) |> string.join("/") |> charlist.from_string())
  load_file(filename |> atom.create_from_string())
  Nil
}

fn build() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles the source-code into a beam instruction bytecode binary",
  )
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let assert [file_ident, ..] = string.split(path, "/") |> list.reverse()
  let assert [filename, _] = string.split(file_ident, ".") |> list.reverse()
  build_src(path, filename)
  Nil
}

fn build_src(path: String, filename: String) -> Nil {
  let assert Ok(src) = simplifile.read(path)
  let assert Ok(prelude) = simplifile.read("./prelude/prelude.lisp")
  io.debug(prelude)
  let src = prelude <> "\n" <> src

  let tokens = lexer.new(src) |> lexer.lex
  tokens |> io.debug
  let ast = tokens |> parser.parse()
  ast |> io.debug
  let compiler = compiler.new(filename) |> compiler.compile_exprs(ast)
  compiler |> io.debug
  let beam_module =
    chunk.compile_beam_module(compiler) |> bytes_tree.to_bit_array()
  beam_module |> io.debug

  let assert Ok(Nil) = simplifile.write_bits(filename <> ".beam", beam_module)
  Nil
}

pub fn main() {
  glint.new()
  |> glint.with_name("lisp")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(["build"], build())
  |> glint.add(["run"], run())
  |> glint.run(argv.load().arguments)
}
