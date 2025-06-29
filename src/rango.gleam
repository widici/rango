import argv
import compiler/chunk
import compiler/compiler
import error
import gleam/bytes_tree
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
fn add_path(path: charlist.Charlist) -> Nil

@external(erlang, "code", "load_file")
fn load_file(file: atom.Atom) -> Nil

fn load() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles source-code into a beam instruction bytecode binary and attempts loading the beam file with code:load_file/2",
  )
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let assert [file_ident, ..dir_path] =
    string.split(path, "/") |> list.reverse()
  let assert [file_name, _] = string.split(file_ident, ".")
  case build_src(path, file_name) {
    Ok(_) -> {
      add_path(
        list.reverse(dir_path) |> string.join("/") |> charlist.from_string(),
      )
      load_file(file_name |> atom.create_from_string())
      Nil
    }
    Error(error) ->
      error.to_string(error)
      |> io.print_error()
  }
}

fn build() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles source-code into a beam instruction bytecode binary",
  )
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let assert [file_ident, ..] = string.split(path, "/") |> list.reverse()
  let assert [file_name, _] = string.split(file_ident, ".")
  case build_src(path, file_name) {
    Ok(_) -> Nil
    Error(error) ->
      error.to_string(error)
      |> io.print_error()
  }
}

fn build_src(path: String, file_name: String) -> Result(Nil, error.Error) {
  let assert Ok(src) = simplifile.read(path)
  let assert Ok(prelude) = simplifile.read("./prelude/prelude.lisp")
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
  let assert Ok(Nil) = simplifile.write_bits(file_name <> ".beam", beam_module)
  Ok(Nil)
}

pub fn main() {
  glint.new()
  |> glint.with_name("lisp")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(["build"], build())
  |> glint.add(["load"], load())
  |> glint.run(argv.load().arguments)
}
