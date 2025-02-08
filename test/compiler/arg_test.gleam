import compiler/arg
import gleeunit/should

pub fn encode_arg_test() {
  [
    #(arg.X, arg.Label, <<19>>),
    #(arg.F, arg.Label, <<21>>),
    #(arg.F, arg.Move, <<13, 64>>),
    #(arg.X, arg.GcBif2, <<11, 125>>),
    #(arg.F, arg.GcBif2, <<13, 125>>),
  ]
  |> encode_arg_test_helper
}

fn encode_arg_test_helper(tests: List(#(arg.Tag, arg.OpCode, BitArray))) {
  case tests {
    [first, ..rest] -> {
      arg.encode_arg(arg.new() |> arg.add_tag(first.0) |> arg.add_opc(first.1))
      |> should.equal(first.2)
      encode_arg_test_helper(rest)
    }
    _ -> Nil
  }
}
