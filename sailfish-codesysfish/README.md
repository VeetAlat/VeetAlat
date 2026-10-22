# CodeSysFish for Sailfish OS

Write **IEC 61131-3 Structured Text** on your phone, the way CODESYS writes
it, and **run it like a PLC**. CodeSysFish compiles your code with clear
error messages, runs `PLC_PRG` cycle after cycle, and shows every variable
live in an online view, where you can flip inputs and write values while
it runs.

Made by Valatalo. Not affiliated with CODESYS GmbH; CODESYS is their
trademark.

## What's in the app

- **Projects:** a list of your programs, saved on the phone as you type.
  It starts with five examples: Blinker, Traffic light, Tank level, Box
  counter, and Arrays and functions. Pull down for a new project (empty,
  or from an example); press and hold one to rename, duplicate or delete
  it.
- **Editor:**
  - **Syntax highlighting** in a monospace font: keywords, types,
    standard functions and blocks, numbers and times, strings and
    comments.
  - **A bar of symbols and snippets** above the keyboard (`:=`, `;`,
    `( )`, `[ ]`, `IF … END_IF`, `FOR`, `CASE`, `T#`...). Snippets
    follow the current indentation, and Enter keeps it.
  - **Build** lists errors and warnings with their lines; tap one to go
    there, and the first error's line is underlined.
  - **Run** builds, loads and starts the PLC.
- **Online view:**
  - **Every variable of the running program, live.** Function blocks,
    structs and arrays open up; other PROGRAMs and global variables are
    groups of their own.
  - **Changing values:** tap a BOOL to flip it, or anything else to write
    a new value (checked as you type).
  - **Controls:** Start, Stop, Step (one cycle), Reset (initial values),
    and the cycle time (10 ms to 1 s).
  - **Runtime errors** (division by zero, an index out of range, an
    endless loop caught by the watchdog) stop the PLC; tap the message to
    see the line.
- **Cover:** the project, Running/Stopped/Error, the cycle count and a
  play/pause button.
- **ST reference:** every part of the language with an example (tap to
  copy).

## The language

| | Supported |
|---|---|
| POUs | `PROGRAM`, `FUNCTION`, `FUNCTION_BLOCK`; `PLC_PRG` runs (or the first PROGRAM); programs can call each other |
| Variables | `VAR`, `VAR_INPUT`, `VAR_OUTPUT`, `VAR_IN_OUT`, `VAR_TEMP`, `VAR CONSTANT`, `VAR_GLOBAL` (`RETAIN`/`PERSISTENT` accepted) |
| Types | `BOOL`, `SINT` `INT` `DINT` `LINT`, `USINT` `UINT` `UDINT` `ULINT`, `BYTE` `WORD` `DWORD` `LWORD`, `REAL` `LREAL`, `TIME`, `STRING(n)`, `ARRAY[a..b, c..d] OF`, `STRUCT`, enums, aliases |
| Values | `16#FF`, `2#1010`, `1_000`, `1.5E3`, `INT#5`, `T#1h2m3s4ms`, `'text $N'`, array `[1, 2, 3(0)]` and struct `(x := 1)` initial values |
| Statements | `:=`, `S=`, `R=`, `IF/ELSIF/ELSE`, `CASE` (lists, ranges, enums), `FOR … BY`, `WHILE`, `REPEAT`, `EXIT`, `CONTINUE`, `RETURN` |
| Operators | `NOT`, `**`, `* / MOD`, `+ -`, comparisons, `AND`/`&`, `XOR`, `OR`, `AND_THEN`, `OR_ELSE` |
| Functions | `ABS SQRT LN LOG EXP EXPT SIN COS TAN ASIN ACOS ATAN TRUNC MIN MAX LIMIT SEL MUX SHL SHR ROL ROR LEN LEFT RIGHT MID CONCAT INSERT DELETE REPLACE FIND TIME()`, every `X_TO_Y` and `TO_Y` |
| Function blocks | `TON TOF TP R_TRIG F_TRIG CTU CTD CTUD SR RS` |

It behaves like a PLC where it matters:
- **Whole numbers wrap around** (an `INT` goes from 32767 to -32768) and
  are worked out in 32-bit registers.
- **Division:** `7 / 2` is 3, and dividing by zero stops the PLC.
- **Conversions:** REAL rounds half away from zero into whole numbers.
- **Types are checked like CODESYS checks them,** with warnings for
  implicit conversions that may lose data.

**Not supported (yet):**
- **Object-oriented ST:** `METHOD`, `PROPERTY`, `INTERFACE`, `EXTENDS`.
- **`POINTER`, `REFERENCE`, `ACTION`, `JMP`.**
- **`AT` addresses:** there's no real I/O.
- **Bit access** like `x.0`.
- **Date and time types:** `DATE`, `TOD`, `DT`, `LTIME`, and also `WSTRING`.

Each of these gets a clear "not supported" message. Numbers are worked out
with JavaScript's precision: `REAL` as 64-bit, and 64-bit whole numbers
exact up to 2^53.

## How it works

- **`qml/js/st.js` is the engine, plain ES5:**
  - a lexer and a recursive-descent parser;
  - a type checker that reports several errors at once, in order;
  - a compiler to JavaScript closures (each expression a function of the
    frame and runtime);
  - a runtime with the standard function blocks, a watchdog (1 s per
    cycle) and a recursion limit.
- **The PLC keeps its own clock:** it runs while the PLC runs and stands
  still while it's stopped. Step is exactly one cycle time, and a gap
  after the phone sleeps counts as at most a second.
- **`src/sthighlighter.cpp`** is a `QSyntaxHighlighter` on the Silica
  `TextArea`'s document. Its word lists come from `st.js`.
- **Projects** are kept in SQLite (LocalStorage) in
  `~/.local/share/org.veetalat/codesysfish/`. The app needs no
  permissions: no network, no files outside its own folder.

## Building and installing

```sh
./build-rpm.sh aarch64      # Docker; RPM lands in RPMS/
devel-su pkcon install-local ~/Downloads/codesysfish-0.1.0-1.aarch64.rpm
```

## Tests

```sh
node tests/test_st.js        # the compiler and runtime: 141 checks
node tests/test_examples.js  # every example and reference sample compiles and runs
tests/sdk-smoke-test.sh      # the app end to end in the Sailfish SDK (Docker)
```

The smoke test runs the real app twice on Sailfish's own Qt 5.6 and
Silica, through its pages:
- opens Blinker with its code highlighted, builds it and runs it;
- watches it blink in the online view, writes a value, steps and resets;
- follows a runtime error to its line, and lists and marks a compile
  error;
- checks that snippets and Enter keep the indentation;
- makes, renames and deletes projects;
- after a restart, checks everything was saved.

## Made with AI-assisted tools

This app has been created using AI generated code (Claude code).
