# EigenLua: the bar and the gap ledger

EigenLua compiles **Lua 5.4** source onto EigenScript. A front end turns `prog.lua` into EigenScript, which then
runs on the real VM (and, later, the AOT). It is rung 1 of the guest-language ladder (hq
`proposals/guest-language-ladder.md`). Its purpose is to press EigenScript's own semantics: integers, strings,
scope and closures, errors, tables, coroutines. Every divergence from reference Lua is either a **front-end bug**
(fixed here) or an **EigenScript gap** (filed upstream and never worked around).

## The oracle

The reference is **PUC-Rio Lua 5.4.9**, built from the release tarball and verified against the SHA-256 that lua.org
publishes:

| file | sha256 |
|---|---|
| `lua-5.4.9.tar.gz` | `2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6` |
| `lua-5.4.9-tests.tar.gz` | `7d971845f545ffc09fbb3128a86b2c6524161c70d0fdf0154a16e8c00c343fca` |

The grader compares a **candidate** command (`<candidate> prog.lua`, same calling convention as `lua prog.lua`)
against the reference on two tiers.

### Tier S: the official test suite

The official suite is assert-based, and its stdout carries timings, random seeds and temporary paths. Those differ
run to run even under the reference (measured on 2026-10-05: `files`, `main`, `math` and `sort` vary), so stdout is
**not** compared here. Each row passes when both of these hold:

1. the candidate exits 0, **and**
2. the candidate executed the same number of `assert` calls as the reference. This is a conserved quantity: a
   candidate that skips work, or exits 0 early, executes fewer.

Population, measured standalone under the reference with `-e "_U=true"` on 2026-10-05: 27 files exit 0.
- `heavy.lua` is excluded; it is a stress test and takes over 120 s.
- `attrib.lua`, `big.lua` and `main.lua` exit non-zero standalone because they need `all.lua`'s setup or a C module.
  Each is listed with that reason, never silently dropped.
- `all.lua`, the driver, is not a row.

### Tier D: the differential corpus

These are small programs written for this repo. Each one is deterministic under the reference: it is run twice and
compared byte for byte, and a nondeterministic program is a corpus defect. The candidate passes a row when its
**stdout and exit status are byte-identical** to the reference's. Each program's header comment names the
EigenScript surface it presses:

- integers vs floats: `math.maxinteger`, values past 2^53, `//` and `%` on negatives, integer overflow wraparound,
  and `1` vs `1.0` printing;
- strings as byte arrays, including embedded `\0` and bytes ≥ 0x80, with `#`, `string.byte`/`char`/`sub`/`rep` and
  `string.format`;
- `local` block scope, closures capturing upvalues (including a loop-variable capture per iteration), and shadowing;
- `pcall`/`error`, error values that are not strings, `error` levels, and `xpcall` with a handler;
- tables: the `#` border, `nil` holes, integer vs float keys (`t[1]` and `t[1.0]` are the same key), `next`/`pairs`
  over insertion and deletion, and metatables (`__index`, `__newindex`, `__eq`, `__lt`, `__call`, `__concat`,
  `__len`);
- coroutines: `resume`/`yield` passing values both ways, `status`, `wrap`, and an error inside a coroutine;
- `goto`, varargs (`...`, `select('#', ...)`, `table.pack`/`unpack`), multiple assignment, and multiple returns
  truncated or expanded by position.

### Tiers × arms

| arm | what runs |
|---|---|
| VM | front end → `.eigs` → `eigenscript` |
| AOT | front end → `.eigs` → ouroboros AOT → native (added once the VM arm has a nonzero score) |

## Exit criteria (this bar does not need to be reachable today)

- Tier S: 27/27 on the VM arm, then on the AOT arm.
- Tier D: every row matches on both arms.
- Every divergence row is classified in the ledger below. Every EigenScript gap has an upstream issue number, and
  every row it touches on EigenScript#1286 has a written measurement.

## Ledger

| row | tier | arm | status | class | issue |
|---|---|---|---|---|---|
| (no front end yet) | | | | | |
