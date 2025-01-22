// TODO: Clean up compile_atom_chunk, replace some compiler.Compiler w/ bytes_tree.BytesTree?, add compile_chunk fn?

import compiler/compiler
import gleam/bit_array
import gleam/bytes_tree
import gleam/dict
import gleam/list
import gleam/string

pub fn compile_beam_header(compiler: compiler.Compiler) -> compiler.Compiler {
  write_string(compiler, "FOR1")
  |> compile_atom_chunk()
  |> write_string("BEAM")
}

/// AtomChunk = <<
///   ChunkName:4/unit:8 = "Atom" | "AtU8",
///   ChunkSize:32/big,
///   NumberOfAtoms:32/big,
///   [<<AtomLength:8, AtomName:AtomLength/unit:8>> || repeat NumberOfAtoms],
///   Padding4:0..3/unit:8
/// >>
fn compile_atom_chunk(compiler: compiler.Compiler) -> compiler.Compiler {
  let chunk = bytes_tree.new()
  // TODO: Is this corret for 32-bits? Needs to be uints?
  bytes_tree.append(chunk, <<dict.size(compiler.atoms):big-size(32)>>)
  compiler.atoms
  |> dict.keys()
  |> list.map(fn(x) {
    [<<string.length(x):big-size(8)>>, bit_array.from_string(x)]
  })
  |> list.map(bit_array.concat)
  |> bit_array.concat()
  |> bytes_tree.append(chunk, _)

  let compiler =
    compiler.Compiler(
      ..compiler,
      data: compiler.data
        |> bytes_tree.append_string("AtU8")
        |> bytes_tree.append(<<bytes_tree.byte_size(chunk):big-size(32)>>)
        |> bytes_tree.append_tree(chunk),
    )
  pad_chunk(compiler)
}

/// Pads the bytes to written compiler.data so that they are 4-byte aligned
pub fn pad_chunk(compiler: compiler.Compiler) -> compiler.Compiler {
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

pub fn write_string(
  compiler: compiler.Compiler,
  string: String,
) -> compiler.Compiler {
  compiler.Compiler(
    ..compiler,
    data: compiler.data |> bytes_tree.append_string(string),
  )
}
