import compiler/chunk
import compiler/compiler
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang
import gleam/io
import gleam/iterator
import gleam/result
import lexer
import parser
import simplifile

pub fn main() {
  let src = erlang.get_line(">>> ") |> result.unwrap("")
  let tokens = lexer.new(src) |> lexer.lex |> iterator.to_list
  tokens |> io.debug
  let ast = parser.Parser(tokens) |> parser.parse
  ast |> io.debug
  let compiler = compiler.new() |> compiler.compile_exprs(ast)
  compiler |> io.debug
  let beam_module =
    chunk.compile_beam_module(compiler) |> bytes_tree.to_bit_array()
  beam_module |> io.debug
  let assert True = beam_module |> bit_array.is_utf8()
  let assert Ok(Nil) = simplifile.write_bits("test.beam", beam_module)
}
