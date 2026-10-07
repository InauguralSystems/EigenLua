# EigenLua round 4: builder report

Branch `frontend/r2`, from round 3's head 5f2722f. Runtime: EigenScript 686d3b7d. Reference: PUC-Rio Lua 5.4.9
from `tools/build_ref.sh`.

## SUMMARY

- **Before** (5f2722f, re-measured at the start of this round):
  `SUMMARY S=2/23 D=63/75 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=98 assert=trusted`
- **After** (`tools/grade.sh --candidate bin/eigenlua --tier all`):
  `SUMMARY S=2/23 D=71/83 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=106 assert=trusted`

There are 8 new D rows, one per front-end bug fixed. `tools/grade.sh --candidate <5f2722f checkout> --only <the 8>`
gives DIVERGE on all 8, and the current head gives MATCH on all 8. The 12 DIVERGE rows are unchanged; all are
EigenScript gaps. No S row's first failure moved: every first failure is still a gap or out of scope.

## Tests

`bash tests/parse_all.sh` (tail):
```
parsed=106/106
```
`bash tests/run.sh` (tail):
```
ROW D xpcall_handler_frame.lua MATCH rc=0
SUMMARY S=23/23 D=83/83 fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=106 assert=trusted
RUN ok

(all 28 PLANT lines in the self-test report OK)
```

## COMMITS

```
d4cef9d gaps/no-string-identity.eigs: %p of a string has no object to name
d147233 xpcall: the message handler runs in the erring Lua frame
26775e6 EIGENLUA-UNSUPPORTED names the nearest Lua caller's line
b0b49ff Uncaught errors print lua.c's traceback on stderr
a85c65e string.gmatch: an init past the end yields no match (pm.lua:344)
8227c07 Keep a Lua call at three VM frames; correct the call-depth gap text
e119839 Locate host-VM errors that escape into Lua code
abaa674 Count C-stack levels as ldo.c does: LUAI_MAXCCALLS 200, 'C stack overflow'
127251c os.exit checks its argument; the stand-alone 'arg' global
8a6b369 debug.traceback: luaL_traceback's level skipping and function names
61b01f0 table.sort: port ltablib.c auxsort/partition/choosePivot, delete the merge sort

(plus the final commit: LEDGER, README, this report)
```

## Items

| item | result | D row |
|---|---|---|
| 1 table.sort | FIXED. ltablib.c `sort`/`auxsort`/`partition`/`choosePivot` are ported with the same geti/seti order (set2 stores the top value first), the `invalid order function for sorting` raise, the `n < INT_MAX` "array too big" check, and `lua_compare(a, b)` operand order. The merge sort is deleted. A random pivot (clock + time) applies only when `up - lo >= 100`. All four reproducers now match: `false invalid order function for sorting`; `bad argument #1 to 'table.sort' (array too big)`; `r1 r3 w1=2 w3=3 r2 r1 w2=2 w1=1`; `attempt to compare string with number`. This also fixed `lr_call` leaving the last C-called function as "current", which made the argument error say `'?'`. | tbl_sort_auxsort.lua |
| 2 traceback | FIXED. The traceback uses luaL_traceback's LEVELS1=10 / LEVELS2=11 with `...\t(skipping N levels)`, global names first, then `main chunk`, then `function <src:line>`. A parallel stack (`lr_fstk`) records the function at each level. A coroutine has no C level below its body. The reproducer prints 24 lines, as the reference does (it printed 45). Names from code (`upvalue 'r'`, `metamethod 'index'`) remain out of scope. | debug_traceback_levels.lua |
| 3 os.exit | FIXED. A boolean, or luaL_optinteger (`number expected, got string`, `number has no integer representation`); the status is taken modulo 256. `pcall(os.exit, "bad")` now returns false. | os_exit_args.lua |
| 4 arg | FIXED. lua.c createargtable: `arg[0]` is the script and `arg[-1]` is the command (`bin/eigenlua` passes `$0`). `print(#arg, arg[0])` prints `0 prog.lua`. | arg_table.lua |
| 5 C stack | FIXED. ldo.c counting: a call from C (site 0), every metamethod call (luaT_callTM), and the generic for's iterator call (OP_TFORCALL) each add one level; `__call` adds none. The limit (200) raises `C stack overflow`, and 220 raises `error in error handling`. pcall/xpcall restore the count. lua.c runs the main chunk at level 2. A resume starts the coroutine one level above its resumer, a fresh body checks the limit, and lower levels are forgotten after a resume. The reproducer prints `false prog.lua:1: C stack overflow` at depth 196, as the reference does. pcall recursion (198), `__newindex`, `__add`, sort comparators, generic for, `__tostring`, `coroutine.wrap` and `gsub` all match the reference's depth and message. | meta_cstack_limit.lua |
| 6 unlocated VM errors | FIXED. A VM error raised in `lr_arith` is located at the operator's site. One raised in a library function is located at its call site (luaL_where(1)); called from C it has no position. The original text is kept: `prog.lua:1: EigenScript value error: pow: result is not a number ...`. The D row checks only the location, since the value itself is the no-nonfinite gap. | err_eigs_located.lua |
| 7 ledger text | FIXED. Re-measured on 686d3b7d: the VM gives 4093 nested calls (bisected); a Lua function recursing under pcall reaches 1362 levels, so a Lua call costs 3.0 frames (lr_call1, lr_call, the function). `gaps/call-depth.eigs` and LEDGER now say this. The round's first C-stack version split lr_call in two and cut depth to 1020 levels; that was reverted to keep three frames. | (text) |
| 8 peel | DONE. See the table. It found 3 more front-end bugs, all fixed: `gmatch` past the end (pm.lua:344, D row `str_gmatch_init_end.lua`); the xpcall handler's frame, the cause of errors.lua's hidden count mismatch at line 528 (D row `xpcall_handler_frame.lua`); and UNSUPPORTED line -1 through pcall (closure.lua:273, diagnostic only, no D form). | 2 rows |

## Peel table

The method and every failure's class are in LEDGER.md, section "Round 4". An uncaught error now prints a traceback on stderr, so a failure inside a helper is blamed on the line that called it.

| row | failures | stop | ref vs cand asserts on the blanked copy |
|---|---|---|---|
| bitwise | 14 (I64, C) | END | 1314 = 1314 |
| closure | 12 (WK hang, OOS upvaluejoin/upvalueid, C) | END | 59 = 59 |
| cstack | 2 (TL, C) | END | 8 = 8 (one CD digit line differs) |
| errors | 13 (OOS, C, CD, NEST) | END | 277 vs 475: CD at 552 (an overflow's handler gets a fresh VM stack); with 549-557 blanked, 274 = 274. Was 275 vs 2453 before items 2 and 8 |
| literals | 9 (NUL, C, unspecified %p) | END | 614 = 614 |
| locals | 8 (I64, OOS, C) | END | 164 vs 160: 4 OOS `getinfo(2).name` asserts in `__close`; with them blanked, 160 = 160 |
| math | 25 (I64, INF, FLT, C) | 25 | not reached |
| nextvar | 18 (I64, FLT, C) | END | ref 9800/9839/9843 (count-unspecified), cand 9814. It no longer hangs |
| pm | 25 (NUL, C, 1 FE fixed, string identity) | 25 | not reached |
| sort | 25 (I64, C) | 25 | not reached |
| tpack | 25 (NUL, I64, C) | 25 | not reached |
| utf8 | 3 (NUL: charpattern, two U+0000 checks) | END | 847 = 847 |
| verybig | 4 (OOS) | END | 5 = 5 |

New gap reproducer: `gaps/no-string-identity.eigs`. `%p` of a string cannot name an object, which affects pm.lua 413, 416 and 426.

## LEDGER counts by class (first failure)

| class | S | D |
|---|---|---|
| EigenScript gap | 15 | 12 |
| out of scope | 6 | 0 |
| front-end bug (open) | 0 | 0 |
| unspecified | 0 | 0 |
| PASS/MATCH | 2 | 71 |

## OUT OF SCOPE

These are unchanged from GAPS.md:
- `debug` except getinfo's currentline/short_src/what, traceback, upvalues and metatables. Traceback names from code (`upvalue 'r'`, `metamethod 'index'`) are out of scope.
- `collectgarbage` counts.
- `string.dump`.
- `io` beyond print/write/stdin.
- `os.tmpname`/`remove`/`date`.

## CAVEATS

- The C-level count follows ldo.c for the boundaries the runtime routes through `lr_call`(site 0), `lr_callmm` and the generic for. A C boundary that the runtime implements without one of these is not counted, such as an internal callback not routed through `lr_call`. After a coroutine yields inside a counted call, the count is clamped at the coroutine's base and not reset exactly.
- A VM error converted at a Lua function's call (not in `lr_arith`) is attributed to the calling line. This is right for a call-depth overflow at entry and approximate elsewhere. No graded row has another case.
- The xpcall handler after a VM call-depth overflow runs on a fresh VM stack, so it does not get Lua's "error in error handling" (errors.lua:557, classed CD).
- Peeling blanks lines. Helper attribution relies on the traceback; where a test body is a function called once, its own line is blanked. Rows that stopped at 25 failures (math, pm, sort, tpack) have unclassified failures after that.
- utf8 and pm were peeled with `utf8.charpattern` replaced by a NUL-free pattern, as in round 3. In utf8, lines 247-256 were also blanked for the count check, since the replacement makes the reference fail there.
- `%p` of a long string is a fresh number on each call. This is a substitute for an identity EigenScript lacks (now a gap reproducer), not a direct translation.
