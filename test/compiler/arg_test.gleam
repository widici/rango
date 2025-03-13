import compiler/arg
import gleam/list
import gleeunit/should

pub fn encode_arg_test() {
  [
    #(arg.X, arg.Label, <<19>>),
    #(arg.F, arg.Label, <<21>>),
    #(arg.F, arg.Move, <<13, 64>>),
    #(arg.X, arg.GcBif2, <<11, 125>>),
    #(arg.F, arg.GcBif2, <<13, 125>>),
  ]
  |> list.each(fn(x) {
    arg.encode_arg(arg.new() |> arg.add_tag(x.0) |> arg.add_opc(x.1))
    |> should.equal(x.2)
  })
}
