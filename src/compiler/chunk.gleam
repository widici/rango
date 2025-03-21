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
pub fn compile_beam_module(compiler: compiler.Compiler) -> bytes_tree.BytesTree {
  let chunks =
    [compile_atom_chunk, compile_import_chunk, compile_export_chunk]
    |> list.fold(#(compiler, bytes_tree.new()), fn(prev, func) {
      let res = func(prev.0)
      #(res.0, bytes_tree.append_tree(prev.1, res.1))
    })
  bytes_tree.new()
  |> append_name("FOR1")
  |> bytes_tree.append(<<{ 4 + bytes_tree.byte_size(chunks.1) }:big-size(32)>>)
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
    bytes_tree.from_bit_array(<<dict.size(compiler.atoms):big-size(32)>>)
    |> bytes_tree.append(
      compiler.atoms
      |> dict.keys()
      |> list.map(fn(x) {
        <<string.length(x):big-size(8), bit_array.from_string(x):bits>>
      })
      |> bit_array.concat(),
    )

  #(compiler, compile_chunk("AtU8", data))
}

/// ImportChunk = <<
///   ChunkName:4/unit:8 = "ImpT",
///   ChunkSize:32/big,
///   ImportCount:32/big,
///   [ << ModuleName:32/big,
///        FunctionName:32/big,
///        Arity:32/big
///     >> || repeat ImportCount ],
///   Padding4:0..3/unit:8
/// >>
fn compile_import_chunk(
  compiler: compiler.Compiler,
) -> #(compiler.Compiler, bytes_tree.BytesTree) {
  let data =
    bytes_tree.from_bit_array(<<dict.size(compiler.imports):big-size(32)>>)
    |> bytes_tree.append(
      compiler.imports
      |> dict.keys()
      |> list.map(fn(x) {
        let #(module, name, arity) = x
        <<module:big-size(32), name:big-size(32), arity:big-size(32)>>
      })
      |> bit_array.concat(),
    )

  #(compiler, compile_chunk("ImpT", data))
}

/// ExportChunk = <<
///   ChunkName:4/unit:8 = "ExpT",
///   ChunkSize:32/big,
///   ExportCount:32/big,
///   [ << FunctionName:32/big,
///        Arity:32/big,
///        Label:32/big
///     >> || repeat ExportCount ],
///   Padding4:0..3/unit:8
/// >>
fn compile_export_chunk(
  compiler: compiler.Compiler,
) -> #(compiler.Compiler, bytes_tree.BytesTree) {
  let data =
    bytes_tree.from_bit_array(<<dict.size(compiler.exports):big-size(32)>>)
    |> bytes_tree.append(
      compiler.exports
      |> dict.to_list()
      |> list.map(fn(x) {
        let #(name, compiler.CompiledFunc(label, arity)) = x
        <<name:big-size(32), arity:big-size(32), label:big-size(32)>>
      })
      |> bit_array.concat(),
    )
  #(compiler, compile_chunk("ExpT", data))
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
/// Will panic if name isn't 4 bytes long
pub fn append_name(
  data: bytes_tree.BytesTree,
  name: String,
) -> bytes_tree.BytesTree {
  let assert 4 = string.byte_size(name)
  bytes_tree.append_string(data, name)
}
