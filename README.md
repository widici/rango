# Rango

> [!WARNING]
> This project is in early development expect some issues and code-breaking changes

Rango is a small toy programming language targeting BEAM bytecode with a Lisp-inspired syntax, written in Gleam.

<details>
<summary>Table of Contents</summary>

1. [Examples](#examples)
1. [Installation](#installation)
1. [Usage](#usage)
    1. [Build](#build)
    1. [Run](#run)
    1. [Load](#load)
1. [Performance](#performance)
1. [Inspiration/Resources](#inspirationresources)
1. [License](#license)
1. [Roadmap](#roadmap)

</details>

## Examples

```lisp
(fn greet [Str name] (
    (putsln (<> "Hello " name "! :D"))
))
```

More examples can be found in the [examples directory](./examples).

## Installation

## Usage

For a quick overview of the cli the help command can be used:

```sh
rango --help
```

### Build

The build command compiles the source-code read from the provided path and outputs a beam file in the current working directory. The subcommand is used like this:

```sh
rango build <file_path>
```

Although the [run command](#run) is generally recommended the beam file can also be executed using Erlang's built in REPL, which doesn't require recompiling to run an already compiled program. It can be used like this:

```sh
$ erl
> code:add_path(".").
> code:load_file(<file_name>).
> <file_name>:<function_name>(<params>).
```

Full example with [fibonacci example program](./examples/fib.lisp):

```sh
$ rango build ./examples/fib.lisp
$ erl
> code:add_path(".").
> code:load_file(fib).
> fib:fib(0, 1, 10).
```

### Run

The program can also be ran directly using the run subcommand which firstly compiles the program (even if it's unchanged) and then runs it, like this:

```sh
rango run <file_path> <function_name> <..params>
```

The params are in this case Erlang terms split with spaces without an ending dot.

Here is the same example with the [fibonacci example program](./examples/fib.lisp) but with the run command instead:

```sh
rango run ./examples/fib.lisp fib 0 1 10
```

### Load

There is also the load subcommand that compiles and validates the BEAM file with the [code/load_file:1](https://www.erlang.org/doc/apps/kernel/code.html#load_file/1) Erlang function. This is also done with the [run subcommand](#run) but the load command doesn´t also run the program, the load command can be used like this:

```sh
rango load <file_path>
```

This subcommand is mainly meant to be used for quick debugging while developing the langauge itself.

## Performance

## Inspiration/Resources

## License

The Rango programming language is distributed under the MIT license. See [LICENSE](./LICENSE) for more information.

## Roadmap

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

- [x] Parse literals, keywords and operators
- [x] Parse lists
- [x] Parse parameters
- [x] Parse spans for expressions

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
- [x] Compile booleans and conditional expressions
- [x] Compile if expressions
- [ ] Add dynamic type checking for user defined functions through beam instructions

### Miscellaneous

- [x] Read source-code from file instead of basic REPL
- [x] Read & use a basic prelude written in the language
- [x] Add better error handling
- [x] Add license
- [x] Add examples
- [x] Add a build, load & run subcommand
- [ ] Add a list of resources and/or inspiration to the README
- [ ] Add language documentation
