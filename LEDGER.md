# EigenLua front end: divergence ledger (round 4)

Every row of `tools/grade.sh --candidate bin/eigenlua --tier all` that is not PASS/MATCH, classified.

- **Runtime:** EigenScript `main` at `686d3b7d14837efb7e6e2b55882190d1dd20a332` (EigenScript#1647, with the real
  `bool`). Its `--version` prints `0.44.0`.
- **Reference:** PUC-Rio Lua 5.4.9 from `tools/build_ref.sh`.
- **Grader verdict, end of round 4:**
  `SUMMARY S=2/23 D=71/83 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=106 assert=trusted`.
- **Before this round** (round 3, 5f2722f): `SUMMARY S=2/23 D=63/75 fail=16 diverge=12 hang=1 crash=0 unsupported=4
  examined=98 assert=trusted`.

Tier D has 83 rows. Round 3 added 23 programs and round 4 added 8, one per front-end bug fixed; each DIVERGEs on
the round before it and MATCHes now (lists at the end). The 12 rows that do not match are the same 12 as in round 2,
all EigenScript gaps.

## Classes

| class | meaning |
|---|---|
| `front-end bug` | Fixed here, with a Tier D program. Open ones are listed as open. |
| `EigenScript gap` | The direct value mapping (owner decision 1) meets something EigenScript cannot represent or do. Each has a reproducer under `gaps/`, with its output on 686d3b7d. |
| `out of scope` | The row stops in a region GAPS.md declares out of scope: most of `debug`, `collectgarbage` counts, `string.dump`, and `io` beyond print/write/stdin. The front end exits 3 (UNSUPPORTED) there, or the out-of-scope value is wrong. |
| `unspecified` | Behaviour the manual leaves open. |

A row's class is the class of its **first failure**. Its first ten failures were found by peeling (below).

## Counts (by first failure)

| class | rows | S | D |
|---|---|---|---|
| EigenScript gap | 27 | 15 | 12 |
| out of scope | 6 | 6 | 0 |
| front-end bug (open) | 0 | 0 | 0 |
| unspecified | 0 | 0 | 0 |
| PASS / MATCH | 73 | 2 | 71 |

No row's first failure is a known front-end bug. That is a claim about **graded rows only**. Probing beyond the corpus keeps finding front-end bugs: the round-4 blind critic found seven more, all pre-existing, filed as EigenLua #13-#20 (plus a `%p` collision on #12), and math.lua's peel past 25 failures holds three of them (#15). Those open bugs are tracked as issues, not counted in this table, because no graded row's first failure is one of them. Round 3's ledger
said the same and was wrong: the round-3 critic found six open front-end bugs (round 4 items 1-6: table.sort
was a merge sort, `debug.traceback` did not skip levels, `os.exit` did not check its argument, no `arg`, no C-stack
limit, unlocated VM errors), and round 4's peel found three more (gmatch past the end, the xpcall handler's frame,
an unlocated UNSUPPORTED line). All are fixed. Open front-end limitation: the compile speed of `load`
(constructs.lua). Rows peeled in round 4 (section below) were peeled to their end or 25 failures; the other S rows
keep round 3's ten.

## How the S rows were peeled

For each S row, in a scratch copy of the suite directory: run `bin/eigenlua` on the file, take the first failure's
line from its message, blank that line (keeping the line count), and run again, up to ten failures. Where blanking
cut a multi-line statement in half, the resulting syntax error was blanked too and not counted. Where the failing
line was inside a helper (`checkerror`, `dostring`, `PU`, `f1`), the calling line was blanked instead where it
mattered, so later checks still ran. A run with no position (an EigenScript arithmetic error) was located with a
scratch build that adds the site's line to such errors. Hangs were located by reading the file.

Abbreviations: **I64** `no-int64`, **FLT** `no-float-subtype`, **INF** `no-nonfinite`, **NUL** `nul-in-string`,
**TC** `no-tail-calls`, **CD** `call-depth`, **WK** `no-weak-refs`, **TL** `task-limit`, **NEST** `expr-nesting`
(EigenScript gaps); **OOS** out of scope; **C** a consequence of the failure before it (or of blanking it); **FE**
a front-end bug, fixed this round.

## Gap reproducers

Each is run as `eigenscript gaps/<file>`. This is its stdout on 686d3b7d.

| file | gap | stdout | rows it explains |
|---|---|---|---|
| `no-int64.eigs` | No 64-bit integer, so values past 2^53 round and nothing wraps. `math.maxinteger` is the double 2^63, which has no integer representation. | `9007199254740992` / `9.223372036854776e+18` / `true` | D: int_maxinteger, int_past53, int_wrap, rng_xoshiro. S: bitwise, locals, math, nextvar, sort, tpack (hex wrap). |
| `int64-for-count.eigs` | An instance of no-int64: `for i = maxinteger - 1, maxinteger` cannot count 2 rounds, both bounds are 2^63. | `true` / `true` | None graded (round-3 critic). nextvar.lua's loops over maxinteger end now but count wrongly (690-704). |
| `no-float-subtype.eigs` | One number type, so 1.0 cannot be told from 1. | `1` / `1` / `3` / `9007199254740992` / `true` | D: int_one_vs_one, ops_matrix, str_format_num. S: math (41), nextvar (624). |
| `no-nonfinite.eigs` | No inf/nan. Overflow saturates at 1e308, and x/0 raises. | `1e+308` / `division by zero` | D: num_print, ops_matrix. S: events, math. |
| `nul-in-string.eigs` | Strings are NUL-terminated. | `1` / `chr of 0: strings are NUL-terminated ...` | D: str_byte_char_sub_rep, str_embedded_nul, str_len, utf8_lib. S: literals, pm, strings, tpack, utf8, calls (313). |
| `call-depth.eigs` | 4093 VM frames, against Lua's 200000 levels; a Lua call costs three frames, so a program overflows at 1362 Lua levels (round 3 said about 5000 frames and two per call). | `{"kind": "limit", "message": "call stack overflow", "line": 18}` | S: calls (111), errors (553). |
| `no-tail-calls.eigs` | No proper tail calls. | `{"kind": "limit", "message": "call stack overflow", "line": 13}` | S: calls (119, 122, 176). |
| `no-weak-refs.eigs` | No weak references and no finalizers. | `[{"x": 1}]` (and `eigenscript --api` lists no weak/finalizer builtin) | S: closure (HANG), gengc, coroutine (417), gc. |
| `task-limit.eigs` | At most 255 live tasks; EigenLua runs each coroutine as one. | `task_spawn: too many live tasks (max 255)` / `255` | S: cstack (105). |
| `expr-nesting.eigs` | The parser refuses an expression about 60 levels deep; each Lua operator or constructor is a call with a list, two levels. Round 2 hoisted every 16th level to dodge this; round 3 removed that workaround. | `51` / `eval: parse error in code string` | S: errors (639, 100 nested table constructors). |
| `list-literal-cap.eigs` | A list literal holds at most 1024 elements. Round 2 split long literals; round 3 removed that workaround. | `1024` / `eval: parse error in code string` | None graded. |
| `nesting-limits.eigs` | 64 indentation levels and 128 compile-nesting levels, against Lua's ~200. | `eval: parse error in code string` / `eval: compile error in code string` | None graded (errors.lua's deeper testrep cases would reach it). |
| `subscript-nesting.eigs` | Each subscript in one expression leaks a nesting level. Round 2 kept subscripts out of loaded chunks to dodge this; round 3 removed that workaround. | `300` / `eval: parse error in code string` | None graded. |
| `no-string-identity.eigs` | A string has no identity, so `%p` of a string cannot name one object (equal short strings hash alike; each %p of a long string is a fresh number). | `true` / `str` | S: pm (413, 416, 426); literals (225-228, also unspecified). |

## Round 4: peel to the row's end, with a count check

Round 4 re-peeled bitwise, closure, cstack, literals, locals, math, nextvar, pm, tpack, utf8, verybig, sort and
errors with a scripted loop (scratch copy of the suite; run; blank the failing line; repeat). Differences from
round 3's method:
- an uncaught error now prints lua.c's traceback on stderr, so a failure inside a helper function (one defined
  once and called at least twice: `checkerror`, `check`, `eqT`, `checkmove`, `f1`, `checkfor`, ...) is attributed
  to its calling line, which is blanked instead;
- a syntax error caused by blanking part of a multi-line statement is blanked too and not counted (`SYN`);
- after ten failures the peel went on while the failures stayed gap/OOS, to the row's end or 25 failures;
- where the peel reached the end, the reference (`lua-count`) and the candidate were both run on the blanked copy
  and their assert counts and stdout compared.

| row | failures (line: class) | end | ref vs cand on the blanked copy |
|---|---|---|---|
| bitwise.lua | 18, 20, 21, 22 I64; 43 I64 (`%d` of maxinteger); 44 C; 47 I64; 53 I64; 61, 63 I64; 72, 73, 74 I64 (bwcoercion's hex strings wrap mod 2^64); 241 I64 (`0xaaaaaaaa << 30` is past 2^53) | END | 1314 = 1314, stdout same |
| closure.lua | 37 WK (37-40 blanked, the HANG); 262 OOS (`upvalueid` of a C function); 265, 268, 270 OOS (`upvaluejoin`); 266, 271 C; 273-278 OOS (`upvaluejoin` through pcall) | END | 59 = 59, stdout same |
| cstack.lua | 105 TL (1000 suspended coroutines); 108 C | END | 8 = 8; stdout differs only in the digit line `final count:` of the xpcall(loop, loop) test (CD; the grader ignores digit lines) |
| errors.lua | 239 OOS (236-240 blanked: `setuservalue`, raised inside a loaded chunk); 280, 287 OOS (`string.dump`); 282, 289 C; 557 CD (the handler of a stack overflow runs on a fresh EigenScript stack, so its own `pcall(loop)` overflows normally instead of "error in error handling"); 651, 658, 659 NEST; 655, 656 NEST (64 indentation levels, `nesting-limits`) | END | 277 vs 475. The 198 extra are line 552 (CD, the 557 case: the handler fails and is re-run 200 times). With 549-557 also blanked: 274 = 274, stdout differs only in three CD digit lines. Before round 4's traceback and xpcall fixes this check gave 275 vs 2453 (the critic's finding). |
| literals.lua | 11 NUL (via the `dostring` helper); 12 C; 27 NUL; 126 NUL (`string.char(0)`); 127 SYN; 225, 226, 227, 228 unspecified (`%p` of equal long strings, `no-string-identity`) | END | 614 = 614, stdout same |
| locals.lua | 88 I64 (88-105 blanked: `until p <= 0` waits for overflow); 262 OOS (`getinfo(2).name`); 463 C of OOS (the `__close` handlers' `getinfo(2).name == "pcall"`); 493 OOS (traceback names); 797, 804 OOS (`sethook`); 806 C | END | 164 vs 160: the four `getinfo(2).name` asserts at 429, 435, 444, 452 (OOS) raise, so the assert after each is skipped. With those blanked: 160 = 160, stdout same |
| math.lua | 13 I64; 29, 30 INF; 41 FLT; 99-103 INF; 104 C; 116-120 I64; 137, 138, 144, 145 FLT (`1 // 0.0` is integer division by zero here); 155, 159 I64; 176 INF; 188 I64; 211, 216 I64 | 25 failures | not reached |
| nextvar.lua | 77 I64; 78, 79 C; 534 I64; 536 C; 628, 631 FLT (`checkfloat`); 629, 632 C; 640 I64; 641 C; 690, 692, 694, 698, 703, 704 I64 (`checkfor` over maxinteger). The round-3 HANG no longer happens: these loops now end (and fail) | END | count-unspecified: 3 reference runs gave 9839, 9843, 9800; cand 9814; stdout same |
| pm.lua | `utf8.charpattern` replaced by a NUL-free pattern (NUL); 27, 29, 31, 33, 35 NUL; 118 NUL; 131 NUL (`abc` is cut at its NUL); 141, 143, 145, 146, 147 C; 234 NUL; **344 FE (fixed: gmatch past the end)**; 397, 398, 399, 400, 401, 402, 403, 406 NUL; 413, 416, 426 `no-string-identity` (%p of a string and of the same string returned by gsub) | 25 failures | not reached |
| sort.lua | 50, 51, 54 I64 (`checkerror("too many results", unpack, {}, 0, maxI)`); 57, 64, 65, 66 I64; 68, 69, 70 I64; 128 I64; 130, 134 C; 136, 139, 142 I64; 137, 140, 143 C; 174-177 I64 (`checkmove` over maxI); 182, 183 I64 | 25 failures | not reached |
| tpack.lua | 51, 53, 54, 55 NUL; 68, 69, 70 NUL; 75 I64; 76, 77, 78 C; 81 I64; 82, 84, 85, 86 C; 89, 90 NUL; 97 I64; 99, 100, 101 C; 117, 118 NUL; 161 NUL | 25 failures | not reached |
| utf8.lua | `utf8.charpattern` replaced by a NUL-free pattern (NUL; lines 22, 83, 248); 218, 236 NUL (`check` of strings holding U+0000, via the helper); 247-256 blanked for the count check (the gmatch loop over a string holding U+0000; with the NUL-free pattern the reference itself fails there) | END | 847 = 847, stdout same |
| verybig.lua | 141 OOS (`os.tmpname`); 147 OOS (`io.close`); 148 OOS (`dofile` of the file); 149 OOS (`os.remove`) | END | 5 = 5, stdout same |

The peel found these front-end bugs, all fixed with D rows:
- pm.lua:344, `gmatch` with an init past the end matched once (`str_gmatch_init_end.lua`);
- errors.lua's count check (528, 275 vs 2453): `debug.traceback` did not skip levels (`debug_traceback_levels.lua`),
  and an xpcall handler did not run in the erring Lua frame (`xpcall_handler_frame.lua`);
- closure.lua:273: EIGENLUA-UNSUPPORTED from a stub called through pcall said line -1 (diagnostic only, fixed;
  no D row, since the exit-3 path cannot match the reference).

## Tier S (23 rows)

The assert-trust probe matches the reference, so every row runs (`assert=trusted`), and every row's negative control
fails correctly.

| row | verdict | count (ref) | class | first ten failures (line: class); round 3. Rows re-peeled in round 4 are in the section above |
|---|---|---|---|---|
| bitwise.lua | FAIL | 3 (1326) | EigenScript gap | 18 I64 (`0xFFFFFFFFFFFFFFFF` must be -1); 20, 21, 22 I64; 43 I64 (`%d` of maxinteger); 44 C; 47 I64; 53 I64 (`1 << 63`); 61, 63 I64 (shift by maxinteger). |
| calls.lua | FAIL | 28 (20114) | EigenScript gap | 119 TC (`deep(30000)`); 111 CD; 120 C; 122 TC; 123 C; 176 TC (tail calls through 100 `__call`s); 313 NUL; 314 OOS (`getinfo(f).source`); 331 OOS (`string.dump`); 332 C. |
| closure.lua | HANG | none | EigenScript gap | 37 WK (`while x[1]` waits for a weak entry); 262 OOS (`upvalueid` of a C function); 265, 268, 270 OOS (`upvaluejoin`); 266, 271 C. Then it ends (exit 3 in a later `upvaluejoin`). |
| constructs.lua | FAIL | 5374 (209484) | out of scope | 306 OOS (`getinfo(1, "n").name`). With that line blanked the rest of the file passes (209482 asserts, the 2 missing being the blanked line's) but takes 469 s, far past the row's budget (20 × the reference's seconds): about 200000 `load`s, at about 1 ms each through the EigenScript-hosted compiler. **Open front-end limitation (speed), not a wrong answer.** |
| coroutine.lua | UNSUPPORTED | 107 (309) | out of scope | 349 OOS (`debug.sethook`); 352 C; 417 WK (`collectgarbage()` must clear a weak entry). Then it runs to the end (301 asserts). Round 2's first failure, line 238 (`getinfo(2).what` inside `__close` during unwinding), was a front-end bug, not out of scope as round 2 filed it; it is fixed. |
| cstack.lua | FAIL | 261 (1206) | EigenScript gap | 105 TL (1000 suspended coroutines). With that block blanked the file passes, with the same count as the reference on the same copy (8). |
| db.lua | UNSUPPORTED | 0 | out of scope | 16 OOS (`gethook`); 33, 34 OOS (`getinfo` option checks); 42, 45, 47 OOS (`name`, `func`, `activelines`); 55 OOS (`string.dump`); 56, 57 C; 91 OOS (`name`, `namewhat`). Line 38 (`getinfo(print).short_src == "[C]"`) was a front-end bug, fixed. |
| errors.lua | UNSUPPORTED | 88 (295) | out of scope | 239 OOS (`setuservalue` on a light userdata); 280 OOS (`string.dump`); 281, 283 C; 287 OOS; 553 CD (stack overflow inside the message handler); 639 NEST (100 nested table constructors). Then the file runs to the end. |
| events.lua | FAIL | 154 (444) | EigenScript gap | 168 INF (`1/0`). With that line blanked the file runs to the end (436 asserts). Lines 180 (`__len` gets its operand twice) and 464 (`debug.setmetatable(10, mt)`) were front-end bugs, fixed. |
| gc.lua | FAIL | 5010 (5169) | out of scope | 194 OOS (`gcinfo`); 201 OOS (`collectgarbage("step")`); 217 OOS (waits for `gcinfo()` to grow: a hang); 261 WK; 262 C; 277 WK; 278 C; 293 WK; 298 C; 301 WK. |
| gengc.lua | FAIL | 18 (19) | EigenScript gap | 122 WK. Then it runs to the end. |
| goto.lua | **PASS** | 65 | | |
| literals.lua | FAIL | 1 (877) | EigenScript gap | 11 NUL (a chunk holding `'a\0a'`); 12 C; 27 NUL; 126 NUL (`string.char(0)` is empty); 225, 226, 227, 228 unspecified (`%p` of two equal long strings: whether the compiler shares one string object is not specified, and an EigenScript string has no identity). Line 252 (`"\n\r"` counted as two line breaks) was a front-end bug, fixed. Then it runs to the end. |
| locals.lua | FAIL | 2175 (2735) | EigenScript gap | 88-104 I64 (`until p <= 0` waits for overflow; past 2^53 the loaded chunk's `a == 2^i` fails); 262 OOS (`getinfo(2).name`); 463 C of 451 OOS (`getinfo(2).name` in `__close`); 493 OOS (`traceback` function names); 797, 804 OOS (`sethook`); 574, 576 C. Then it runs to the end. |
| math.lua | FAIL | 3 (floor 28124) | EigenScript gap | 13 I64; 29, 30 INF; 41 FLT (`math.type(0.0)`); 99, 100, 101, 102, 103 INF; 104 C. |
| nextvar.lua | FAIL | 210 (floor 8868) | EigenScript gap | 77 I64 (`next` from maxinteger); 78, 79 C; 534 I64 (`__len` returns maxinteger); 536 C; 624 FLT; 635 I64 (a loop from maxinteger); 682 I64. Round 4: the loops over `maxi`/`mini` now end and the row runs to its end (section above). |
| pm.lua | FAIL | 4 (395) | EigenScript gap | 27, 29, 31, 33, 35 NUL; 61 NUL (`utf8.charpattern` holds a NUL). With `utf8.charpattern` replaced by a NUL-free pattern: 118 NUL; 119, 120 C (the `f1` helper's line was blanked); 131 NUL (`abc` is cut at its NUL). |
| sort.lua | FAIL | 14 (258507) | EigenScript gap | 50 I64 (`unpack({}, 0, maxI)` must say "too many results"); 57, 64, 65, 66 I64; 68, 69, 70 I64 (`minI + 1 == minI`); 128 I64; 136 I64. |
| strings.lua | FAIL | 3 (332) | EigenScript gap | 22, 23, 24, 25, 27, 29, 30, 33 NUL; 51 I64; 53 NUL. |
| tpack.lua | FAIL | 6 (471) | EigenScript gap | 51, 53, 54, 55 NUL (packed bytes hold zeros); 68, 69, 70 NUL; 75 I64 (a hex literal that wraps mod 2^64); 76, 77 C. Line 63 (`unpack("i7", ...)` of -1 gave 0) was a front-end bug, fixed. |
| utf8.lua | FAIL | 61 (1193) | EigenScript gap | 57, 83 NUL (`utf8.charpattern`); 85, 87, 89, 90 C; 42, 51, 52 NUL (`check` of strings with U+0000, lines 218 and 236); 80 C. With `utf8.charpattern` replaced and those two checks blanked, the whole file passes (871 asserts). |
| vararg.lua | **PASS** | 80 | | |
| verybig.lua | UNSUPPORTED | 5 | out of scope | 141 OOS (`os.tmpname`); 147 OOS (`io.close`); 148 OOS (`dofile` of the file); 149 OOS (`os.remove`). Then it runs to the end. |

## Tier D: DIVERGE (12 rows)

Unchanged from round 2: each row's first difference, and every differing line of ops_matrix, is one of the gaps.

| row | first difference | class | evidence |
|---|---|---|---|
| int_maxinteger.lua | line 1 `9223372036854775807` vs `9.2233720368548e+18` | EigenScript gap | `no-int64`: maxinteger maps to 2^63. |
| int_one_vs_one.lua | line 2 `1.0` vs `1` | EigenScript gap | `no-float-subtype` |
| int_past53.lua | line 2 `9007199254740993` vs `...992` | EigenScript gap | `no-int64` (line 5 is the float subtype) |
| int_wrap.lua | line 1 mininteger vs `9.2233720368548e+18` | EigenScript gap | `no-int64`: no wrap |
| num_print.lua | line 1 (nothing printed) | EigenScript gap | `no-nonfinite`: its value table holds `1/0`, which raises |
| ops_matrix.lua | line 24 `float -0` vs `integer 0` | EigenScript gap | `no-float-subtype`, `no-int64`, `no-nonfinite` |
| rng_xoshiro.lua | line 3 `math.random(0)` | EigenScript gap | `no-int64`. Floats, ranged integers and seeds match; only full 64-bit integers round. |
| str_byte_char_sub_rep.lua | line 1 `65 0 200` vs `65 nil` | EigenScript gap | `nul-in-string` |
| str_embedded_nul.lua | line 1 `4` vs `1` | EigenScript gap | `nul-in-string` |
| str_format_num.lua | line 11 `1 1.0` vs `1 1` | EigenScript gap | `no-float-subtype` (`%s` of 1.0) |
| str_len.lua | line 3 `3` vs `1` | EigenScript gap | `nul-in-string` |
| utf8_lib.lua | line 9 `utf8.charpattern` bytes | EigenScript gap | `nul-in-string` |

## Front-end bugs fixed in round 3

Each has a Tier D program that DIVERGEs on round 2 (6e6aafe) and MATCHes on round 3.

| D program | bug | found by |
|---|---|---|
| tbc_repeat_until.lua | `repeat local x <close> ... until c` closed x before c ran | reviewer (a) |
| tbc_genfor_close.lua | the generic for's 4th value was never closed | reviewer (b) |
| co_close_yield.lua | a `__close` run by `coroutine.close` could yield; yield errors carried a position | reviewer (d) |
| co_isyieldable_c.lua | `isyieldable` was true inside a C callback (`gsub`) | reviewer (e) |
| io_default_output.lua | `io.output`/`io.input` did not change the default files | reviewer (g) |
| io_read_eof.lua | stdin had no persistent buffer; read formats did not follow liolib.c | reviewer (c) |
| io_file_results.lua | file handles passed table checks; `flush` returned the handle | reviewer (h), (l) |
| str_class_z.lua | `%z` was not the NUL class | reviewer (f) |
| load_shebang.lua | `load` skipped a leading `#` line | reviewer (j) |
| require_searchers.lua | `package.searchers` was unsupported | reviewer (k) |
| debug_upvalue_computed.lua | closures were inspectable only if the source spelled `getupvalue` | reviewer (m) |
| tbc_unwind_frame.lua | `__close` during error unwinding saw a Lua frame below it (coroutine.lua:238) | critic |
| for_string_bounds.lua | a numeric `for` refused string bounds | critic |
| tbl_remove_insert.lua | `table.remove({[0]="ban"})` | critic |
| tbl_len_nonint.lua | a non-integer `__len` gave an EigenScript error | critic |
| lex_error_messages.lua | lexical error messages and near-texts | critic |
| int_conversion_errors.lua | 2^63 was accepted as an integer | critic (and workaround removal) |
| str_frontier_end.lua | frontier patterns at the subject's end | critic |
| str_unpack_signext.lua | `unpack("i7")` lost the sign | peel (tpack.lua:63) |
| lex_line_endings.lua | `"\n\r"` counted as two lines | peel (literals.lua:252) |
| meta_len_args.lua | `__len` got one argument | peel (events.lua:180) |
| meta_type_metatables.lua | `debug.setmetatable` on non-tables was unsupported | peel (events.lua:464) |
| debug_getinfo_func.lua | `getinfo(f)` of a C function said Lua | peel (db.lua:38) |

Two critic reports did not reproduce against the reference: a global assignment inside a parenthesized loaded call
(`0:10 1:10 14:10 20:10` from both arms) and `gsub` with a false/true replacement (identical output and errors).

## Front-end bugs fixed in round 4

Each has a Tier D program that DIVERGEs on round 3 (5f2722f) and MATCHes now.

| D program | bug | found by |
|---|---|---|
| tbl_sort_auxsort.lua | table.sort was a merge sort: no "invalid order function for sorting", no "array too big", lua_geti/lua_seti order and compare operand order not ltablib's (now auxsort/partition/choosePivot) | critic (item 1) |
| debug_traceback_levels.lua | `debug.traceback` printed every level and `function <?>`; now LEVELS1/LEVELS2 skipping, global names, `function <src:line>` | critic (item 2) |
| os_exit_args.lua | `os.exit("bad")` exited 0 (and killed a pcall); now luaL_optinteger | critic (item 3) |
| arg_table.lua | no `arg` global | critic (item 4) |
| meta_cstack_limit.lua | no LUAI_MAXCCALLS: metamethod recursion hit the VM's call-stack overflow at 817; now "C stack overflow" at the reference's depth (196) | critic (item 5) |
| err_eigs_located.lua | a VM error escaping Lua code (pow NaN, x/0, out-of-domain math) had no `chunk:line:` | critic (item 6) |
| str_gmatch_init_end.lua | `gmatch` with an init past the end matched once | peel (pm.lua:344) |
| xpcall_handler_frame.lua | an xpcall handler ran under a C level instead of in the erring Lua frame | peel (errors.lua count check, line 528) |

Also fixed, without a D row: EIGENLUA-UNSUPPORTED from a stub called through pcall reported line -1
(closure.lua:273; the exit-3 path cannot match the reference), and an uncaught error now prints lua.c's traceback
on stderr (Tier D ignores stderr).

## What remains UNSUPPORTED (exit 3)

- **debug:** `sethook`/`gethook`, `getlocal`/`setlocal`, `getregistry`, `getuservalue`/`setuservalue`, `upvaluejoin`,
  `setcstacklimit`, `debug.debug`, and `getinfo` of another coroutine. Out of scope (GAPS.md).
- **Files and processes:** `io.open`, `io.popen`, `io.tmpfile`, `io.close`, `io.lines` with a file name,
  `io.input`/`io.output` with a file name, `os.tmpname`, `os.remove`, `os.rename`, `os.execute`, `os.date`, and
  `os.time` with a table. Out of scope.
- **Other:** `string.dump` and binary chunks; `package.loadlib` and a C searcher that finds a library (C modules);
  `loadfile` from stdin.
- A to-be-closed variable in a block that also holds goto labels. No graded row has one.
