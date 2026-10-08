# EigenLua

Lua 5.4 compiled onto [EigenScript](https://github.com/InauguralSystems/EigenScript). This is rung 1 of the
guest-language ladder: a front end turns Lua source into EigenScript, which runs on the real VM, so a Lua program
inherits EigenScript's observer, trace tape and sandbox.

It is graded against reference Lua 5.4.9 and the official Lua test suite. The bar and the gap ledger are in
[GAPS.md](GAPS.md).

Status: front end round 7. `bin/eigenlua prog.lua` compiles with `src/compile.eigs` (written in EigenScript)
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

Measured 2026-10-08 (round 7, v0.45.1) with `EIGENLUA_TIMEOUT_SCALE=3 bash tests/run.sh`:
`SUMMARY S=23/23 D=112/112 fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=135 assert=trusted`.
Every non-passing row is classified in [LEDGER.md](LEDGER.md) by its first failure:
- 27 are EigenScript gaps, each with a reproducer in `gaps/` (cstack.lua is now a HANG on v0.45.0: it runs past its
  time budget before its unchanged first failure);
- 6 stop first in regions GAPS.md declares out of scope;
- no graded row's first failure is a front-end bug (a claim about graded rows only; probe-found bugs are listed
  by issue in LEDGER.md). Round 5 fixed EigenLua#8, #11-#20, each with a Tier D program, added table-library and
  builtin-value coverage (#2, #3), cut the upvalue query to 1.4% of a call (#9), and attributed `load`'s speed
  (#7, constructs.lua) and pipe reads (#10) to EigenScript gaps with reproducers.
- Round 6 fixed EigenLua#21, #22, #24-#29 (reader read counts, hex-float subnormals, the xpcall handler before
  `__close`, one address space, library argument errors, the generic for's close line, loaded chunks' sites)
  and a probe-found index-error naming bug; `dofile`'s errno text is `gaps/no-errno.eigs`. The grader now refuses a
  duplicate D.manifest line and checks `corpus/builtins.inventory` against the reference's builtins (#21).
- Round 7 fixed EigenLua#35's bad-method-self reason, deferred coroutine-error closing, xpcall handler emergency
  stack depth, and `debug.getinfo(2)` while `coroutine.close` runs a closing method.
- Lua-specific limits the runtime follows: LUAI_MAXCCALLS (C-stack levels, "C stack overflow" at 200), and an
  uncaught error prints lua.c's traceback on stderr.

`tests/parse_all.sh` parses every graded file.
