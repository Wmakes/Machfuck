# Machfuck

Machfuck is a Brainfuck interpreter and Brainfuck-to-Mach transpiler written entirely in [Mach](https://machlang.org/). Both backends consume the same filtered, bracket-validated instruction representation and precomputed loop jump table.

Current version: **1.0.0**.

## Requirements

- Mach 6.10.1 or a compatible 6.x release
- mach-std 9.5.x
- A supported hosted target

Release builds are declared for Linux x86-64, AArch64, and RISC-V 64; Windows x86-64; and macOS x86-64 and AArch64.

The repository pins mach-std under `dep/std` as a Git submodule.

## License and generated programs

Machfuck's source code and distributed Machfuck executable are licensed under
the [MIT License](LICENSE). The [generated-program permission](OUTPUT-PERMISSION.md)
lets you use and distribute Machfuck-authored code copied into generated source
or binaries under terms of your choice, without carrying Machfuck's MIT notice
in those generated files. Your Brainfuck input remains under its own terms.
Third-party components in generated programs, including mach-std, retain their
own licenses and notice requirements.

## Build

```sh
git submodule update --init
mach build . -a machfuck
```

The Linux debug executable is written to:

```text
out/linux-x86_64/debug/bin/machfuck
```

Build an optimized executable with:

```sh
mach build . -a machfuck -p release
```

## Command-line interface

Machfuck includes a built-in help message:

```sh
machfuck --help
```

The complete command line is:

| Invocation | Arguments | Behavior |
|---|---|---|
| `machfuck program.bf` | `program.bf`: readable Brainfuck source file | Parse and interpret the program |
| `machfuck compile program.bf [--target TARGET] [--output DIRECTORY]` | `program.bf`: input source | Build a native executable named `program` (`program.exe` for Windows) |
| `machfuck --help` | None | Print usage, arguments, and options |
| `machfuck --version` | None | Print `Machfuck <version>` |

Supplying no source file, unknown options, extra arguments, or the wrong number of arguments is an error and returns a nonzero status.

### Examples

Interpret a Brainfuck source file:

```sh
machfuck hello.bf
```

Compile a Brainfuck program into a native executable in the current directory:

```sh
machfuck compile hello.bf
./hello
```

Select a target and destination directory:

```sh
machfuck compile hello.bf --target windows-x86_64 --output dist/windows
```

This writes `dist/windows/hello.exe`. Machfuck invokes `mach init --no-git` to create an isolated temporary project with its own `mach.toml`, `src/main.mach`, and mach-std dependency, then invokes `mach build` for the selected target. It places the executable in the requested directory and removes the temporary project. You can run it from any working directory; `mach` must be on `PATH`. A fresh compile needs network access to resolve and download mach-std. Compiler diagnostics appear on standard error.

Mach targets combine the operating system, instruction-set architecture, and ABI. Select one with `-t` when compiling generated source:

| Target | Operating system | Architecture | ABI |
|---|---|---|---|
| `linux-x86_64` | Linux | x86-64 | SysV64 |
| `linux-arm64` | Linux | AArch64 | AAPCS64 |
| `linux-riscv64` | Linux | RISC-V 64 | LP64 |
| `windows-x86_64` | Windows | x86-64 | Win64 |
| `darwin-x86_64` | macOS | x86-64 | SysV64 |
| `darwin-aarch64` | macOS | AArch64 | AAPCS64 |

The default target is `linux-x86_64`. Cross-compiled executables can be built on the development machine, but need their target operating system or a compatible runner to execute.

The generated source uses the same 30,000-byte tape, checked pointer movement, wrapping arithmetic, byte I/O, and EOF behavior as the interpreter. The source can also be inspected or modified before it is compiled.

Diagnostics are written to standard error. Standard output is reserved for bytes produced by the interpreted Brainfuck program.

## Releases

Run `.github/workflows/release.yml` manually from GitHub Actions or with:

```sh
gh workflow run release.yml \
  --ref main \
  -f version=1.0.0 \
  -f publish_release=false
```

`version` must match `[project].version` in `mach.toml`. When `publish_release` is `true`, the workflow creates `v<version>` in GitHub Releases; otherwise it only uploads the packages as a workflow artifact. Every run tests Machfuck and packages all six declared release targets. GitHub provides the artifact and release download metadata.

Validate a version locally with:

```sh
tools/check-version.sh 1.0.0 out/linux-x86_64/debug/bin/machfuck
```



## Brainfuck instructions

| Instruction | Operation |
|---|---|
| `>` | Move the data pointer right |
| `<` | Move the data pointer left |
| `+` | Increment the current byte, wrapping from 255 to 0 |
| `-` | Decrement the current byte, wrapping from 0 to 255 |
| `.` | Write the current cell as one raw byte |
| `,` | Read one raw byte into the current cell |
| `[` | Skip to the matching `]` when the current cell is zero |
| `]` | Return to the matching `[` when the current cell is nonzero |

Every other source byte is treated as a comment and ignored.

## Architecture

Machfuck has four main components:

1. The source loader reads the complete file into owned memory.
2. The parser filters comments, validates brackets with a stack, and creates loop jumps in linear time.
3. The virtual machine executes the parsed representation without allocating inside its execution loop.
4. The transpiler converts that same representation into a standalone Mach entry module with native Mach loops and operations.

This shared representation keeps interpreter and transpiler semantics aligned and provides a place for future optimization passes.

## Memory and EOF behavior

Each execution allocates one tape of 30,000 unsigned 8-bit cells and initializes it to zero. The data pointer begins at cell zero. Moving before the first cell or beyond the final cell is a runtime error; Machfuck never deliberately performs the invalid access.

Cell arithmetic wraps explicitly. It does not depend on compiler overflow behavior.

The `,` instruction reads exactly one byte. At end of input, the current cell is set to zero.

## Errors

Machfuck returns a nonzero status for invalid command lines, unreadable files, allocation failures, unmatched brackets, tape-boundary violations, and input/output failures. Parser and runtime messages go to standard error.

The compiler validates the complete program before invoking Mach. An invalid target, a missing Mach installation, or a failed build returns a nonzero status.

## Tests

Run the automated integration suite with:

```sh
tests/run.sh
```

The suite rebuilds Machfuck and verifies raw output bytes for arithmetic, wrapping, comments, input, EOF, simple and nested loops, zero-cell loop skipping, invalid brackets, both tape boundaries, CLI errors, and missing files. It also emits Mach source, compiles that source with the installed Mach compiler, and executes the resulting native programs.

## Benchmark snapshot

On an AMD Ryzen 5 5600X with Mach 6.10.1 in release mode, the [MIT-licensed Sierpiński program](https://github.com/mohanson/brainfuck/blob/master/res/sierpinski.bf) produced identical 1,744-byte output in interpreter and native modes. Median wall time over five batches of 1,000 end-to-end executions was 1.980 ms per interpreted run and 1.598 ms per native run (1.24×). These are machine-specific measurements from the earlier source-emission backend. The current automatic compile path has not been rebenchmarked; it invokes the same generated-code backend. Large programs can produce substantial Mach source and compilation time because instructions are not yet folded.

## Known limitations

- The tape size is fixed at 30,000 cells.
- Each compile currently creates a temporary Mach project and resolves mach-std; a fresh compile can spend time downloading its dependency and needs network access.
- The shared instruction representation currently preserves individual Brainfuck operations; run-length folding and higher-level loop optimizations are future work.
- Generated programs use the same fixed tape and checked pointer semantics as the interpreter.
- Interactive mode, tracing, debugging, execution counters, dynamic tapes, and JIT compilation are not implemented.
