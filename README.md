# EigenLua

Lua 5.4 compiled onto [EigenScript](https://github.com/InauguralSystems/EigenScript). This is rung 1 of the
guest-language ladder: a front end turns Lua source into EigenScript, which runs on the real VM, so a Lua program
inherits EigenScript's observer, trace tape and sandbox.

It is graded against reference Lua 5.4.9 and the official Lua test suite. The bar and the gap ledger are in
[GAPS.md](GAPS.md).

Status: front end round 2. `bin/eigenlua prog.lua` compiles with `src/compile.eigs` (written in EigenScript)
and runs the result on the EigenScript VM: `$EIGENSCRIPT`, else `eigenscript` on `PATH`. It needs the `bool` type,
which arrived at EigenScript `main` 686d3b7d (EigenScript#1647).

The runtime library has these parts:
- `src/runtime.eigs`;
- Lua patterns (`rt_pattern`);
- `string.format` (`rt_format`);
- math with a bit-exact xoshiro256** (`rt_math`);
- `utf8` (`rt_utf8`);
- coroutines on cooperative tasks (`rt_coroutine`);
- io handles (`rt_io`);
- `string.pack` (`rt_pack`).

`goto`, `<close>`, `load`/`require`, `_ENV` and the in-scope `debug` functions are compiled.

Measured 2026-10-07 with `tools/grade.sh --candidate bin/eigenlua --tier all`:
`SUMMARY S=2/23 D=40/52 fail=17 diverge=12 hang=1 crash=0 unsupported=3 examined=75 assert=trusted`.
Every non-passing row is classified in [LEDGER.md](LEDGER.md):
- 27 are EigenScript gaps, each with a reproducer in `gaps/`;
- 6 stop in regions GAPS.md declares out of scope;
- none is a known front-end bug.

`tests/parse_all.sh` parses every graded file.

