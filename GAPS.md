# EigenLua: the bar and the gap ledger

EigenLua compiles **Lua 5.4** source onto EigenScript. A front end turns `prog.lua` into EigenScript, which then
runs on the real VM (and, later, the AOT). It is rung 1 of the guest-language ladder (hq
`proposals/guest-language-ladder.md`). Its purpose is to press EigenScript's own semantics: integers, strings,
scope and closures, errors, tables, coroutines.

Every ledger entry is exactly one of:
- a **front-end bug**, fixed here;
- an **EigenScript gap**, filed upstream and never worked around;
- **unspecified** behavior, fixed in the corpus;
- **out of scope**, listed below and never graded.

## The oracle

The reference is **PUC-Rio Lua 5.4.9**, built from the release tarball and verified against the SHA-256 that lua.org
publishes:

| file | sha256 |
|---|---|
| `lua-5.4.9.tar.gz` | `2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6` |
| `lua-5.4.9-tests.tar.gz` | `7d971845f545ffc09fbb3128a86b2c6524161c70d0fdf0154a16e8c00c343fca` |

**The reference is pure Lua 5.4, as its manual defines it.** 5.4.9's own `src/Makefile` hard-codes `-DLUA_COMPAT_5_3`.
That turns on `LUA_COMPAT_MATHLIB` (`math.pow` and friends) and `LUA_COMPAT_LT_LE` (`__lt` standing in for a missing
`__le`), both removed by manual §8.1. `/code-review` caught that the first reference builds had it.
- `tools/build_ref.sh` strips the flag and then checks every built binary: `math.pow == nil`, and `<=` with only
  `__lt` raises. The build stops otherwise (plant `compat-ref`).
- Re-measured without the flag, only `meta_lt.lua`'s reference output changed. It now requires the 5.4 rule.
- A hand-supplied `--ref` is not re-checked by `grade.sh`. Run `tools/build_ref.sh --check-not-compat <bin>` on it
  first.

`tools/build_ref.sh` builds these binaries from that one tarball, all without the compat flag (plus test-only `lua-toothless` and `lua-compat` for plants):

| binary | difference | used for |
|---|---|---|
| `lua` | pristine | Tier D reference |
| `lua-count` | `tools/ref-count.patch`: `luaB_assert` increments a C counter; `atexit` prints `EIGENLUA-ASSERTS:<n>` on stderr | Tier S reference, and the canary |
| `lua-seedA`, `lua-seedB` | `luai_makeseed` fixed to two different constants | hash-layout check on the Tier D corpus |

The grader runs a **candidate** as `<candidate> prog.lua` and nothing else. Both arms run on the same machine, OS and
libc in the same grader invocation, so float printing (`%.14g`, `nan`/`-nan`, `inf`) is compared like for like.
Reproducing `%.14g` exactly is the front end's job.

### Tier S: the official test suite

Both arms receive the **unmodified** suite file. The candidate reports how many times its `assert` builtin was
called by printing `EIGENLUA-ASSERTS:<n>` on stderr at exit; the front end counts in its runtime, in native code.
The counters on both arms are invisible to the `debug` library by construction. Native functions fire no line
hooks, which is why `db.lua` passes.

The suite's stdout carries timings, seeds and paths that vary run to run, so stdout is not compared byte for byte.
A row passes when all of these hold:
1. the candidate exits 0;
2. it prints exactly one numeric count line;
3. its **progress lines**, meaning the stdout lines that contain no digit, equal the reference's;
4. its count equals the reference's.

**The candidate's `assert` is checked before Tier S trusts it.** A Tier S pass means the file's assertions held only if
the candidate's `assert` actually raises. A blind critic showed the gap: a candidate whose `assert` never raises, with
`string.upper` broken as well, passed 18 of 23 rows. So before any S row, the grader runs `corpus/D/assert_semantics.lua`
on the candidate and requires byte-identical output. The program checks that `assert`:
- raises on `false` and `nil`;
- does not raise on `0`, `""` or `{}`;
- passes messages and non-string error values through;
- returns all of its arguments.

On a mismatch every S row is `FAIL assert-untrusted` (plant `toothless`).

The probe alone is not enough. A second critic showed that a front end compiling DIRECT calls `assert(c, m)` into an
inline intrinsic that never raises passed a probe that used `assert` only as a value. So both of these hold:
- The probe also makes direct calls on failing values: in closures, loops, nested functions, and `assert(f())` where
  `f` returns nothing.
- **Every graded row has a negative control.** The candidate runs on that exact file with `assert(false);` put in
  front of line 1, with no newline, so line numbers do not move. It must exit non-zero with `assertion failed!`, or
  the row is `FAIL assert-untrusted(control)` (plant `callsite-toothless`). The reference must fail the control too.
  The control's measured cost, on an idle box, is about 1.2 s for both arms over all 23 rows.

**Tier S trusts the VALUES fed to `assert`, so Tier D enumerates them.** A fourth critic showed that a candidate
whose `not` returns integer `0`, which is truthy, instead of `false` passed 21 of 23 S rows with a trusted `assert`.
Every `assert(not …)` in those files could no longer fail. Adding more probe shapes only moves that hole outward.
Instead, Tier D's `ops_matrix.lua` applies every Lua 5.4 operator to a fixed set of 17 values:
- all 4 unary operators;
- all 21 binary operators over every pair of values (`lparser.c`'s `getunopr`/`getbinopr` in 5.4.9).

It prints each result's type and value, or `err`, and it also prints truthiness through `if` and `while`. The
grader exits 2 unless that program's operator table equals the operator list declared in `corpus/D.manifest`
(plant `ops-drop`).

**So a grade means BOTH tiers.** Tier S alone can read 21/23 for a candidate that Tier D marks wrong. Only
`S=N/N D=M/M` (exit 0) is a pass. Value bugs in builtins, beyond the operators and the string library, are
enumerated by coverage rows (`builtin_values.lua`, `builtin_values_more.lua`, `tbl_library.lua`, ...), and the
grader checks `corpus/builtins.inventory` (EigenLua#21): it must list exactly the reference's globals and library
fields, each cited by a D row that names it or declared uncovered with a reason (plants `builtin-missing`,
`builtin-uncited`); a D.manifest line given twice exits 2 (plant `dup-manifest`).

**Declared residual:** a front end whose `assert` is correct on line 1 and in every probe shape, but toothless at some
other call site, would pass. That needs a compiler that treats identical call sites differently by position. It is
not covered.

The candidate's count is self-reported, so it is never trusted alone:
- a missing count fails (plant `no-count`);
- a forged count with an early exit fails on the progress lines (plant `lying-count`);
- an off-by-one count fails on the count (plant `off-by-one`).

**Class `count-unspecified`.** Some files execute a number of asserts that the manual does not determine. Measured
2026-10-05:
- `math.lua` calls `math.randomseed()` with no argument (line 845), which seeds from the clock. Over 40 reference runs
  the count ranged from 46823 to 131654.
- `nextvar.lua` asserts once per `_G` entry visited before `print`, and `next()` order follows the string hash seed.
  Over 40 runs it ranged from 9849 to 9934.

For these rows, condition 4 is replaced by: count ≥ ⌊f × (minimum over 20 reference runs)⌋, where f is declared per
row in `corpus/S.manifest`. A count-unspecified row with no declared f, or with an f outside the open interval (0, 1), is a harness error. There is no upper bound:
the progress lines catch a late exit, and the floor catches an early one.

| row | f | measured over 1220 reference runs | what a candidate can skip |
|---|---|---|---|
| `math.lua` | 0.60 | counts come in steps of 10602 (one per repeat of a float-random loop), so the min-of-20 itself varies; a reference run fell below a 20-run floor about 2e-5 of the time at 0.60, and about 1.8e-3 at 0.77 | about 64% of a median run; about 22% of the smallest run |
| `nextvar.lua` | 0.90 | the counts range from 9838 to 9942 (max/min = 0.9895), so a 0.90 floor never lands above a real run | about 10% |

**Number printing is graded on purpose.** The manual leaves number-to-string formatting to the implementation, but
every program prints numbers, and a guest that prints them differently from `lua` is useless in practice. Tier D's
`num_print.lua` therefore pins PUC-Rio's rule: `%.14g`, with `.0` appended to integral floats. It also covers
`inf`/`-inf`/`-0.0`, `2^53`, `2^63` and `math.pi`. The sign of NaN is NOT graded, since C prints `nan` or `-nan`;
NaN is checked only through `0/0 ~= 0/0`.

Randomness that IS specified is graded exactly. The 5.4 manual specifies xoshiro256**, its seeding, and its float
and range mapping, so `rng_xoshiro.lua` in Tier D requires the candidate's `math.random` to be bit-exact.

**Population: 23 graded rows** (21 exact plus 2 `count-unspecified`). Every exclusion has a reason in `corpus/S.manifest`, and none is silently dropped.
- `heavy.lua`: a stress test, over 120 s.
- `attrib.lua`, `big.lua`, `main.lua`: they fail standalone and need `all.lua`'s setup or a C module.
- `api.lua`, `code.lua`: they run no assertions without the internal `T` test library.
- `bwcoercion.lua`, `tracegc.lua`: helpers with no standalone assertions.
- `files.lua`: excluded. With a regular file on stdin it fails at `files.lua:84`, because `io.stdin:seek` succeeds;
  with a pipe, its `io.popen` children each report their own count. `io.popen` is out of scope, see below.
- `all.lua` is the driver, not a row.

### Tier D: the differential corpus

These are small programs written for this repo. The candidate passes a row when its **stdout and exit status are
byte-identical** to the reference's. Each program's header names the EigenScript surface it presses: integers vs
floats, byte strings, the string library (patterns, `gsub`, character classes, `%b`, frontier patterns, `utf8`, `format`), `assert` itself, scope and closures, errors, tables and metatables, coroutines, `goto`, varargs, multiple
assignment and returns, and `math.random`.

The corpus itself is checked on every run:
- **Deterministic:** every program runs twice under `lua-seedA` with identical output.
- **Layout-independent:** every program runs under `lua-seedB` with output identical to `lua-seedA`. A difference
  means the program prints string-key traversal order, so it is UNSPECIFIED: a corpus defect, exit 2.
- **Audited by hand for what the seed cannot see** (one `unspecified-audit` line per program in `corpus/D.manifest`):
  which border `#t` returns when a table has holes, and the order of numeric keys in the hash part.

### Unspecified behavior is a ledger class, not a gap

The Lua 5.4 manual leaves these to the implementation:
- `pairs`/`next` order;
- the border `#t` returns when a table has holes (§3.4.7);
- `tostring` of tables, functions and threads;
- number formatting, which this repo nevertheless grades against PUC-Rio's `%.14g` on purpose (see Tier S);
- the sign of NaN.

A Tier D program must not print any of these. It sorts keys, takes `#t` only of sequences, or checks that the result
IS a valid border and prints that boolean. A divergence that traces to unspecified behavior is fixed in the corpus.

### Front-end decision, day one: source positions are output

`error("x")` raises `prog.lua:12: x`, and runtime errors carry the same `chunkname:line:` prefix. A program that
prints a caught message exposes it on stdout. **The front end preserves the chunk name and the original Lua line
numbers through compilation**:
- for `error` at levels 1 and 2;
- for runtime errors (arithmetic on nil, calling or indexing a nil value);
- in `assert` messages.

Runtime-error wording follows PUC-Rio's where the program can observe it. Where the wording depends on debug names
the front end cannot know, the row is reclassified with that reason, never faked.

### Out of scope (never graded, never a ledger failure)

- `string.dump` and loading binary chunks;
- the C API and C modules;
- most of `debug` (hooks, `getinfo` beyond `currentline`/`short_src`, `getlocal`/`setlocal`, `upvalueid`/`upvaluejoin`,
  `getregistry`);
- `collectgarbage` counts and step results;
- the values of `os.time`, `os.clock`, `os.date` and `os.getenv`;
- `io` beyond `print`, `io.write` and stdin reads, including `io.popen`.

A Tier S row that fails only inside an out-of-scope region is listed with that reason rather than counted as a gap.

### Tiers × arms

| arm | what runs |
|---|---|
| VM | front end → `.eigs` → `eigenscript` |
| AOT | front end → `.eigs` → ouroboros AOT → native (added once the VM arm has a nonzero score) |

## Exit criteria (this bar does not need to be reachable today)

- Tier S: every included row passes on the VM arm, then on the AOT arm.
- Tier D: every row matches on both arms.
- Every divergence row is classified in the ledger below. Every EigenScript gap has an upstream issue number, and
  every row it touches on EigenScript#1286 has a written measurement.

## Ledger

| row | tier | arm | status | class | issue |
|---|---|---|---|---|---|
| (no front end yet) | | | | | |
