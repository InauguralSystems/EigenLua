# EigenLua

Lua 5.4 compiled onto [EigenScript](https://github.com/InauguralSystems/EigenScript). This is rung 1 of the
guest-language ladder: a front end turns Lua source into EigenScript, which runs on the real VM, so a Lua program
inherits EigenScript's observer, trace tape and sandbox.

It is graded against reference Lua 5.4.9 and the official Lua test suite. The bar and the gap ledger are in
[GAPS.md](GAPS.md).

Status: front end round 1. `bin/eigenlua prog.lua` compiles with `src/compile.eigs` (written in EigenScript) and
runs the result on EigenScript v0.44.0. Measured 2026-10-06 with
`tools/grade.sh --candidate bin/eigenlua --tier all`:
`SUMMARY S=0/23 D=13/47 fail=23 diverge=12 hang=0 crash=0 unsupported=22 examined=70 assert=untrusted`.
Every non-passing row is classified in [LEDGER.md](LEDGER.md); the EigenScript gaps behind them have reproducers
in `gaps/`. `tests/parse_all.sh` parses all 70 graded files.
