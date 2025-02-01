import compiler/compiler
import gleam/erlang
import gleam/io
import gleam/iterator
import gleam/result
import lexer
import parser

pub fn main() {
  let src = erlang.get_line(">>> ") |> result.unwrap("")
  let tokens = lexer.new(src) |> lexer.lex |> iterator.to_list
  tokens |> io.debug
  let ast = parser.Parser(tokens) |> parser.parse
  ast |> io.debug
  let compiler = compiler.new() |> compiler.compile_exprs(ast)
  compiler |> io.debug
}
