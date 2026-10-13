# Contributing to EigenLua

Thanks for your interest. EigenLua compiles Lua 5.4 onto [EigenScript](https://github.com/InauguralSystems/EigenScript):
a front end (`src/compile.eigs`, written in EigenScript) turns `prog.lua` into EigenScript, which runs on the real VM.
Its job is to press EigenScript's own semantics — integers, strings, closures, errors, tables, coroutines — against a
language with a precise, well-tested reference. See the [README](README.md) for status and [GAPS.md](GAPS.md) for the
bar.

## Setup

EigenScript is not vendored. Either open the repo in a devcontainer or
[Codespace](https://codespaces.new/InauguralSystems/EigenLua), which builds the pinned EigenScript (see
`.devcontainer/Dockerfile`, `EIGS_REF`), or build it yourself and put `eigenscript` on `PATH` (or set `EIGENSCRIPT`).

```sh
bin/eigenlua prog.lua                         # compile and run one Lua program
tools/build_ref.sh                            # build reference Lua 5.4.9 (the oracle) from vendor/
tools/grade.sh --candidate bin/eigenlua --tier D   # grade against the reference
bash tests/run.sh                             # the full suite CI runs
```

On a slow machine, `EIGENLUA_TIMEOUT_SCALE=3 bash tests/run.sh` scales the suite's timeouts.

## The discipline (what makes a good contribution here)

- **Reference Lua is the oracle.** Tier D programs must print byte-for-byte what PUC-Rio Lua 5.4.9 prints, with the
  same exit code. Tier S runs the official Lua test suite unmodified. A divergence is never explained away.
- **Every non-passing row is exactly one thing** (GAPS.md): a front-end bug (fixed here), an EigenScript gap (filed
  upstream), unspecified behavior (fixed in the corpus), or out of scope (listed, never graded). Record it in
  [LEDGER.md](LEDGER.md).
- **EigenScript gaps go upstream — never work around them.** If the VM can't express a Lua semantic (64-bit integers,
  the float subtype, NUL bytes in strings, `inf`/`nan`), add a minimal reproducer under `gaps/` and file an issue in
  [EigenScript](https://github.com/InauguralSystems/EigenScript). A shim in the runtime library hides exactly the signal
  this project exists to produce.
- **New behavior gets a Tier D program.** Add a small `corpus/D/<name>.lua` that exercises it; the grader diffs it
  against the reference automatically, so there is no expected output to hand-write.

## Before you open a PR

- `bash tests/run.sh` passes (CI runs it on every PR, and `main` requires it).
- If you changed graded behavior, include the `SUMMARY` line from `tools/grade.sh` before and after.
- Keep the prevailing style of the file you touch.

## Good first contributions

Issues labelled [good first issue](https://github.com/InauguralSystems/EigenLua/labels/good%20first%20issue) are small
and self-contained. Adding a Tier D program for a library corner that isn't covered yet is always welcome.

## Reporting bugs

Open an issue with the smallest Lua program that shows the difference, plus reference Lua's output and EigenLua's.
For security concerns use private vulnerability reporting (Security tab) or email contact@inauguralsystems.com.
