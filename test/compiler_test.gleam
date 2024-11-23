import compiler
import gleeunit/should

pub fn encode_arg_test() {
  [
    #(compiler.X, compiler.Label, <<19>>),
    #(compiler.F, compiler.Label, <<21>>),
    #(compiler.F, compiler.Move, <<13, 64>>),
    #(compiler.X, compiler.GcBif2, <<11, 125>>),
    #(compiler.F, compiler.GcBif2, <<13, 125>>),
  ]
  |> encode_arg_test_helper
}

fn encode_arg_test_helper(
  tests: List(#(compiler.Tag, compiler.OpCode, BitArray)),
) {
  case tests {
    [test_case, ..rest] -> {
      compiler.encode_arg(test_case.0, compiler.int(test_case.1))
      |> should.equal(test_case.2)
      encode_arg_test_helper(rest)
    }
    _ -> Nil
  }
}
