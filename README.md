# EigenLua

Lua 5.4 compiled onto [EigenScript](https://github.com/InauguralSystems/EigenScript). This is rung 1 of the
guest-language ladder: a front end turns Lua source into EigenScript, which runs on the real VM, so a Lua program
inherits EigenScript's observer, trace tape and sandbox.

It is graded against reference Lua 5.4.9 and the official Lua test suite. The bar and the gap ledger are in
[GAPS.md](GAPS.md).

Status: front end round 4. `bin/eigenlua prog.lua` compiles with `src/compile.eigs` (written in EigenScript)
and runs the result on the EigenScript VM: `$EIGENSCRIPT`, else `eigenscript` on `PATH`. It needs the `bool` type,
which arrived in EigenScript v0.45.0 (EigenScript#1647).

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

Measured 2026-10-07 (round 4) with `tools/grade.sh --candidate bin/eigenlua --tier all`:
`SUMMARY S=2/23 D=71/83 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=106 assert=trusted`.
Every non-passing row is classified in [LEDGER.md](LEDGER.md) by its first failure:
- 27 are EigenScript gaps, each with a reproducer in `gaps/`;
- 6 stop first in regions GAPS.md declares out of scope;
- no first failure is a front-end bug. Round 4 fixed the six front-end bugs the round-3 critic found and three
  more found by peeling 13 S rows to their end (or 25 failures), each with a Tier D program. Where a peel reached
  the end, the reference and EigenLua give the same assert count on the blanked copy, or the difference is
  classified (errors.lua: call depth; locals.lua: `getinfo(...).name`, out of scope). Open front-end limitation:
  `load` compiles too slowly for constructs.lua's 200000 chunks.
- Lua-specific limits the runtime follows: LUAI_MAXCCALLS (C-stack levels, "C stack overflow" at 200), and an
  uncaught error prints lua.c's traceback on stderr.

`tests/parse_all.sh` parses every graded file.

