# Rango

> [!IMPORTANT]
> This project is in early development expect some issues and code-breaking changes

Rango is a small compiled toy programming language targeting BEAM bytecode with a Lisp-inspired syntax, written in Gleam.

<details>
<summary>Table of Contents</summary>

1. [Examples](#examples)
1. [Prerequisites](#prerequisites)
1. [Installation](#installation)
    1. [From release](#from-release)
    2. [From source](#from-source)
1. [Usage](#usage)
    1. [Build](#build)
    1. [Run](#run)
    1. [Load](#load)
1. [Inspiration/resources](#inspirationresources)
1. [Roadmap](#roadmap)
1. [License](#license)

</details>

## Examples

```lisp
(fn greet [Str name] (
    (putsln (<> "Hello " name "! :D"))
))
```

More examples can be found in the [examples directory](./examples).

## Prerequisites

> [!NOTE]
> Erlang and Rebar3 does not come prepackaged, when installing Gleam, in every package manager. 

- [Gleam](https://gleam.run/getting-started/installing/#installing-gleam)
- [Erlang](https://gleam.run/getting-started/installing/#installing-erlang)
- [Rebar3](https://gleam.run/getting-started/installing/#installing-rebar3)

## Installation

### From release

Download the escript from the [nightly release](https://github.com/widici/rango/releases/tag/nightly) and add it to PATH.

### From source

Clone the repository:

```sh
# Either with SSH:
git clone git@github.com:widici/rango.git

# ... or with HTTPS:
git clone https://github.com/widici/rango.git
```

Build the project:

```sh
gleam build
```

Generate the escript:

```sh
gleam run -m gleescript
```

And then add the file to PATH.

## Usage

For a quick overview of the cli the help command can be used:

```sh
rango --help
```

### Build

The build command compiles the source-code read from the provided path and outputs a beam file in the current working directory. The subcommand is used like this:

```console
rango build <file_path>
```

Although the [run command](#run) is generally recommended the beam file can also be executed using Erlang's built in REPL, which doesn't require recompiling to run an already compiled program. It can be used like this:

```console
$ erl
> code:add_path(".").
> code:load_file(<file_name>).
> <file_name>:<function_name>(<params>).
```

Full example with [fibonacci example program](./examples/fib.lisp):

```console
$ rango build ./examples/fib.lisp
$ erl
> code:add_path(".").
> code:load_file(fib).
> fib:fib(0, 1, 10).
```

### Run

The program can also be ran directly using the run subcommand which firstly compiles the program (even if it's unchanged) and then runs it, like this:

```console
rango run <file_path> <function_name> <..params>
```

The parameters are in this case Erlang terms split with spaces without an ending dot.

Here is the same example with the [fibonacci example program](./examples/fib.lisp) but with the run command instead:

```sh
rango run ./examples/fib.lisp fib 0 1 10
```

### Load

There is also the load subcommand that compiles and validates the BEAM file using the [code/load_file:1](https://www.erlang.org/doc/apps/kernel/code.html#load_file/1) Erlang function. The [run command](#run) also does this but additionally runs the code itself, which can be unwanted. The load command can be used like this:

```console
rango load <file_path>
```

This subcommand is mainly meant to be used for quick debugging while developing the langauge itself.

## Inspiration/resources

- [The Bada programming language](https://github.com/tsoding/bada) & [Tsoding's stream](https://www.youtube.com/watch?v=6k_sR6yCvps&list=PLpM-Dvs8t0VY3Z6U756L08xySMlGdRrF8&index=2&t=1606s)
- [The beam_makeops script documentation](https://www.erlang.org/doc/apps/erts/beam_makeops.html)
- [A brief introduction to BEAM](https://www.erlang.org/blog/a-brief-beam-primer/)
- [A peak into the Erlang compiler and BEAM bytecode](https://gomoripeti.github.io/beam_by_example/)
- and many more! :D

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
- [x] Create a GitHub workflow for creating a nightly release on push
- [x] Add prerequisites & installation instructions
- [x] Add a list of resources and/or inspiration to the README
- [ ] Add language documentation

## License

The Rango programming language is distributed under the MIT license. See [LICENSE](./LICENSE) for more information.
