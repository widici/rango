# Lisp

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Todo

### Lexer

- [x] Lex Literals (Strings, Integers, Booleans, etc.)
- [x] Lex basic operators (e.g. arithmetic operators)

### Parser

- [x] Parse basic expressions with operators via lists

### Compiler

- [x] Encode arguments with tags and opcodes
- [x] Compile Literals (Integers for now)
- [x] Compile basic mathematical expressions (add, sub, mul for now)
- [ ] Add Beam file header
- [ ] Compile atom table chunk
- [ ] Compile import & export table chunk

### Miscellaneous

- [ ] Improve docs
- [ ] Add better error handling
- [ ] Add examples
- [ ] Unit testing for the parts above
