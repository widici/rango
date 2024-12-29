import gleam/dict

/// Used for finding the id of a func based on the atom-ids of the module:func/arity
pub type Imports =
  dict.Dict(#(Int, Int, Int), Int)

/// Maps an atom represented by a string based on it's corresponding id
/// Using a Dict here instead of a List should provide a better time-compexity in Gleam
pub type Atoms =
  dict.Dict(String, Int)

pub fn get_atom_id(atoms: Atoms, name: String) -> #(Atoms, Int) {
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

pub fn resolve_func_id(
  atoms: Atoms,
  imports: Imports,
  module: String,
  func: String,
  arity: Int,
) -> #(Atoms, Imports, Result(Int, Nil)) {
  let #(atoms, module_id) = get_atom_id(atoms, module)
  let #(atoms, func_id) = get_atom_id(atoms, func)
  #(atoms, imports, #(module_id, func_id, arity) |> dict.get(imports, _))
}
