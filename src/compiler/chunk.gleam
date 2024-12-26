import gleam/dict

/// Used for finding the id of a func based on the atom-ids of the module:func/arity
type ImportTable =
  dict.Dict(#(Int, Int, Int), Int)

/// Connects a atom represented by a string with it's corresponding id
/// Using a Dict here instead of a List should provide a better time-compexity in Gleam
type Atoms =
  dict.Dict(String, Int)

fn get_atom_id(atoms: Atoms, name: String) -> #(Atoms, Int) {
  case dict.has_key(atoms, name) {
    True -> {
      let assert Ok(res) = dict.get(atoms, name)
      #(atoms, res)
    }
    False -> {
      dict.size(atoms) |> dict.insert(atoms, name, _) |> get_atom_id(name)
    }
  }
}

fn resolve_func_sig(
  atoms: Atoms,
  imports: ImportTable,
  module: String,
  func: String,
  arity: Int,
) -> #(Atoms, ImportTable, Result(Int, Nil)) {
  let #(atoms, module_id) = get_atom_id(atoms, module)
  let #(atoms, func_id) = get_atom_id(atoms, func)
  #(atoms, imports, #(module_id, func_id, arity) |> dict.get(imports, _))
}
