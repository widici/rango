import compiler/arg
import compiler/compiler
import gleam/bit_array
import gleam/bytes_tree
import gleam/dict
import gleam/int
import gleam/list
import gleam/string

/// BEAMHeader = <<
///   IffHeader:4/unit:8 = "FOR1",
///   Size:32/big,                  // big endian, how many more bytes are there
///   FormType:4/unit:8 = "BEAM"
/// >>
pub fn compile_beam_module(compiler: compiler.Compiler) -> bytes_tree.BytesTree {
  let chunks =
    [
      compile_import_chunk,
      compile_code_chunk,
      compile_export_chunk,
      compile_string_chunk,
      compile_atom_chunk,
    ]
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

// CodeChunk = <<
//   ChunkName:4/unit:8 = "Code",
//   ChunkSize:32/big,
//   SubSize:32/big,
//   InstructionSet:32/big,        % Must match code version in the emulator
//   OpcodeMax:32/big,
//   LabelCount:32/big,
//   FunctionCount:32/big,
//   Code:(ChunkSize-SubSize)/binary,  % all remaining data
//   Padding4:0..3/unit:8
// >>
fn compile_code_chunk(
  compiler: compiler.Compiler,
) -> #(compiler.Compiler, bytes_tree.BytesTree) {
  let sub_size = 16
  let instruction_set = 0
  let opcode_max = 169
  let compiler =
    compiler |> compiler.add_arg(arg.new() |> arg.add_opc(arg.IntCodeEnd))
  let data =
    bytes_tree.from_bit_array(<<
      sub_size:big-size(32),
      instruction_set:big-size(32),
      opcode_max:big-size(32),
      compiler.label_count:big-size(32),
      dict.size(compiler.exports):big-size(32),
    >>)
    |> bytes_tree.append_tree(compiler.data)
  #(compiler, compile_chunk("Code", data))
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

/// StringChunk = <<
///   ChunkName:4/unit:8 = "StrT",
///   ChunkSize:32/big, Data:ChunkSize/binary,
///   Padding4:0..3/unit:8
/// >>
/// ### Important
/// String chunk is currently unused and only implemented to fill beam requirements
fn compile_string_chunk(
  compiler: compiler.Compiler,
) -> #(compiler.Compiler, bytes_tree.BytesTree) {
  #(compiler, compile_chunk("StrT", bytes_tree.new()))
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
      |> dict.to_list()
      |> list.sort(fn(a, b) { int.compare(a.1, b.1) })
      |> list.map(fn(x) { <<string.length(x.0):big-size(8), { x.0 }:utf8>> })
      |> bit_array.concat(),
    )

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
/// Will panic if name isn't 4 bytes long
pub fn append_name(
  data: bytes_tree.BytesTree,
  name: String,
) -> bytes_tree.BytesTree {
  let assert 4 = string.byte_size(name)
  bytes_tree.append_string(data, name)
}
