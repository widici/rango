import compiler/compiler
import gleam/bit_array
import gleam/bytes_tree
import gleam/list

pub fn compile_beam_header(compiler: compiler.Compiler) {
  write_string(compiler, "FOR1")
  |> write_string("BEAM")
}

// TODO: write tests for this function
fn pad_chunk(compiler: compiler.Compiler) -> compiler.Compiler {
  let times = case bytes_tree.byte_size(compiler.data) % 4 {
    0 -> 0
    rem -> 4 - rem
  }
  compiler.Compiler(
    ..compiler,
    data: list.repeat(<<0x00>>, times)
      |> bit_array.concat()
      |> bytes_tree.append(compiler.data, _),
  )
}

fn write_string(
  compiler: compiler.Compiler,
  string: String,
) -> compiler.Compiler {
  compiler.Compiler(
    ..compiler,
    data: compiler.data |> bytes_tree.append(bit_array.from_string(string)),
  )
}
