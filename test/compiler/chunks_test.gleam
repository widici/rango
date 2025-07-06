import compiler/chunks
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
  |> list.each(fn(x) {
    bytes_tree.byte_size({ bytes_tree.from_bit_array(x) |> chunks.pad_chunk() })
    % 4
    |> should.equal(0)
  })
}
