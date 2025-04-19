# Lisp

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## Todo

### Lexer

- [x] Lex literals (integers, strings, booleans)
- [x] Lex operators (e.g. arithmetic operators, comparison operators, etc.)
- [x] Lex parentheses & square brackets
- [x] Lex special keywords
- [x] Lex regular identifiers
- [x] Improve lexing of literals with the usage of regex
- [x] Lex spans in source-code for tokens
- [x] Lex column and row position for span instead of linear position
- [x] Lex comments

### Parser

- [x] Parse literals, keywords & operators
- [x] Parse lists
- [x] Parse parameters
- [x] Parse spans for expressions
- [ ] Improve parsing of use expressions, etc. to catch errors before compiling

### Compiler

- [x] Encode arguments with tags and opcodes
- [x] Compile integers
- [x] Compile mathematical expressions for operators using GcBif2 (add, sub, mul)
- [x] Add Beam file header
- [x] Compile atom table chunk
- [x] Compile use expressions
- [x] Compile import table chunk
- [x] Compile export table chunk
- [x] Compile string table chunk
- [x] Compile function expressions
- [x] Compile code chunk
- [x] Compile return expressions
- [x] Compile variable definition expressions
- [x] Compile cons expressions
- [x] Compile lists
- [x] Compile internal/local function calls
- [x] Compile external function calls
- [x] Compile strings (charlists)
- [ ] Compile if expressions
- [ ] Add dynamic type checking for user defined functions through beam instructions

### Miscellaneous

- [x] Read source-code from file instead of basic REPL
- [x] Read & use a basic prelude written in the language
- [x] Add better error handling
- [ ] Improve docs
- [ ] Add examples
