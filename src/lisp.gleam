import gleam/erlang
import gleam/io
import gleam/iterator
import gleam/result
import lexer

pub fn main() {
  let src = erlang.get_line(">>> ") |> result.unwrap("")
  let tokens = lexer.new(src) |> lexer.lex
  io.debug(1)
  tokens |> iterator.to_list |> io.debug
  io.debug(2)
}
