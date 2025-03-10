import argv
import compiler/chunk
import compiler/compiler
import gleam/bit_array
import gleam/bytes_tree
import gleam/io
import gleam/string
import glint
import lexer
import parser
import simplifile

fn build(src: String) -> BitArray {
  let tokens = lexer.new(src) |> lexer.lex
  tokens |> io.debug
  let ast = tokens |> parser.parse()
  ast |> io.debug
  let compiler = compiler.new() |> compiler.compile_exprs(ast)
  compiler |> io.debug
  let beam_module =
    chunk.compile_beam_module(compiler) |> bytes_tree.to_bit_array()
  beam_module |> io.debug
  beam_module
}

fn root_command() -> glint.Command(Nil) {
  use <- glint.command_help(
    "Compiles source-code into beam instruction bytecode",
  )
  use _, args, _ <- glint.command()
  let assert [path, ..] = args
  let assert Ok(src) = simplifile.read(path)
  let assert Ok(prelude) = simplifile.read("./prelude/prelude.lisp")
  io.debug(prelude)
  let beam_module = build(prelude <> "\n" <> src)
  let assert True = beam_module |> bit_array.is_utf8()
  let assert [filename, _extension] = string.split(path, ".")
  let assert Ok(Nil) = simplifile.write_bits(filename <> ".beam", beam_module)
  Nil
}

pub fn main() {
  glint.new()
  |> glint.with_name("lisp")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add([], root_command())
  |> glint.run(argv.load().arguments)
}
