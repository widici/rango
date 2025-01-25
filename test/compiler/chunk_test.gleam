import compiler/chunk
import gleam/bit_array
import gleam/bytes_tree
import gleam/list
import gleeunit/should

pub fn pad_chunk_test() {
  [
    <<0x00>>,
    bit_array.from_string("test"),
    <<123_456_789>>,
    list.repeat(<<0xff>>, 6) |> bit_array.concat(),
  ]
  |> pad_chunk_test_helper
}

fn pad_chunk_test_helper(tests: List(BitArray)) {
  case tests {
    [first, ..rest] -> {
      bytes_tree.byte_size({
        bytes_tree.from_bit_array(first)
        |> chunk.pad_chunk()
      })
      % 4
      |> should.equal(0)
      pad_chunk_test_helper(rest)
    }
    _ -> Nil
  }
}
