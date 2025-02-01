import compiler/compiler
import gleam/bit_array
import gleam/bytes_tree
import gleam/dict
import gleam/list
import gleam/string

/// BEAMHeader = <<
///   IffHeader:4/unit:8 = "FOR1",
///   Size:32/big,                  // big endian, how many more bytes are there
///   FormType:4/unit:8 = "BEAM"
/// >>
pub fn compile_beam_header(compiler: compiler.Compiler) -> bytes_tree.BytesTree {
  let chunks =
    [compile_atom_chunk]
    |> list.fold(#(compiler, bytes_tree.new()), fn(prev, func) {
      let res = func(prev.0)
      #(res.0, bytes_tree.append_tree(prev.1, res.1))
    })
  bytes_tree.new()
  |> append_name("FOR1")
  |> bytes_tree.append(<<bytes_tree.byte_size(chunks.1):big-size(32)>>)
  |> append_name("BEAM")
  |> bytes_tree.append_tree(chunks.1)
}

fn compile_chunk(
  name: String,
  data: bytes_tree.BytesTree,
) -> bytes_tree.BytesTree {
  bytes_tree.new()
  |> append_name(name)
  |> bytes_tree.append(<<bytes_tree.byte_size(data):big-size(32)>>)
  |> bytes_tree.append_tree(data)
  |> pad_chunk()
}

/// AtomChunk = <<
///   ChunkName:4/unit:8 = "Atom" | "AtU8",
///   ChunkSize:32/big,
///   NumberOfAtoms:32/big,
///   [<<AtomLength:8, AtomName:AtomLength/unit:8>> || repeat NumberOfAtoms],
///   Padding4:0..3/unit:8
/// >>
fn compile_atom_chunk(
  compiler: compiler.Compiler,
) -> #(compiler.Compiler, bytes_tree.BytesTree) {
  // TODO: Is this corret for 32-bits? Needs to be uints?
  let data =
    bytes_tree.append(bytes_tree.new(), <<
      dict.size(compiler.atoms):big-size(32),
    >>)

  let data =
    compiler.atoms
    |> dict.keys()
    |> list.map(fn(x) {
      [<<string.length(x):big-size(8)>>, bit_array.from_string(x)]
      |> bit_array.concat()
    })
    |> bit_array.concat()
    |> bytes_tree.append(data, _)

  #(compiler, compile_chunk("AtU8", data))
}

/// Pads the bytes to written compiler.data so that they are 4-byte aligned
pub fn pad_chunk(data: bytes_tree.BytesTree) -> bytes_tree.BytesTree {
  let times = case bytes_tree.byte_size(data) % 4 {
    0 -> 0
    rem -> 4 - rem
  }
  list.repeat(<<0x00>>, times)
  |> bit_array.concat()
  |> bytes_tree.append(data, _)
}

/// Utility function for writting chunk names
/// ### Safety
/// Will panic if name isn't 2 bytes long
pub fn append_name(
  data: bytes_tree.BytesTree,
  name: String,
) -> bytes_tree.BytesTree {
  let assert 4 = string.byte_size(name)
  bytes_tree.append_string(data, name)
}
