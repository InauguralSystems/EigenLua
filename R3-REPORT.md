# EigenLua round 3: builder report

Branch `frontend/r2`, from round 2's head 6e6aafe. Runtime: EigenScript 686d3b7d. Reference: PUC-Rio Lua 5.4.9
from `tools/build_ref.sh`.

## SUMMARY

- **Before** (6e6aafe, re-measured at the start of this round):
  `SUMMARY S=2/23 D=40/52 fail=17 diverge=12 hang=1 crash=0 unsupported=3 examined=75 assert=trusted`
- **After** (`tools/grade.sh --candidate bin/eigenlua --tier all`):
  `SUMMARY S=2/23 D=63/75 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=98 assert=trusted`

The 23 new D rows are one per fixed front-end bug. Each DIVERGEs on 6e6aafe and MATCHes now. The 12 DIVERGE rows
are the same 12 as before, all EigenScript gaps. coroutine.lua went from FAIL (count 83) to UNSUPPORTED (count 107).
It now gets past line 238 and stops at `debug.sethook`, which is out of scope.

## Tests

`bash tests/parse_all.sh` (tail):
```
parsed=98/98
```
`bash tests/run.sh` (tail; it rebuilds the reference, runs the grader self-test with every plant, then the canary):
```
ROW D vararg_pack.lua MATCH rc=0
SUMMARY S=23/23 D=75/75 fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=98 assert=trusted
RUN ok
```
Every plant in the self-test reported OK (see `/tmp/run.log` lines starting `PLANT`).

## COMMITS

- `70a15cf` Restore tests/parse_all.sh from main; population is now exactly 52 D + 23 S
- `6fa3c7c` Remove EigenScript-limit workarounds from the front end
- `de56ad3` Fix the reviewer findings (a)-(h), (j)-(m), each with a Tier D program
- `497a142` Fix the critic's round-3 front-end bugs, each with a Tier D program
- `96daf5a` Fix the front-end bugs the S-row peel found, each with a Tier D program
- `c1e981c` LEDGER for round 3: every S row peeled to its first ten failures
- (this report and the README status line are the final commit)

## Item 1: the grader

`tests/parse_all.sh` is `main`'s file again. The version check (`0.44.0`) and the `==` population check are both
back. Only the expected D count changed: 52, then 63, then 70, and now 75, the exact number of D programs. The
check reads the VM from `$ROOT/.tmp/eigenscript-linux-x86_64`, as on main. In this checkout that path is a symlink
to the built VM. No other grader file changed.

## Workaround inventory (item 2)

| # | place | verdict | reason |
|---|---|---|---|
| 1 | `lr_genv`/`lr_gsetenv` (runtime) + `em_expr1`/`em_assign_to` (emit) | REMOVED | Existed only to keep subscripts out of loaded chunks (EigenScript#1655, `gaps/subscript-nesting.eigs`). A loaded chunk's global now compiles to `lr_index of [ENV[0], name, site]` / `lr_setindex of [ENV[0], ...]`, the same shape as every other upvalue access. |
| 2 | `lr_cell0` (runtime), used for `_ENV` in loaded chunks | REMOVED | Same subscript dodge; `_ENV` is now `ENV[0]`. |
| 3 | `em_listlit` 512-element chunking + `concat` | REMOVED | Existed only for EigenScript's 1024-element list-literal cap. Now one literal; a longer constructor/arg list diverges. Reproducer `gaps/list-literal-cap.eigs`. |
| 4 | `em_expr` hoisting every 16th nesting level into a temp | REMOVED | Existed only for EigenScript's expression-nesting cap. A deep Lua expression is now a deep EigenScript expression and diverges. Reproducer `gaps/expr-nesting.eigs`. |
| 5 | `lr_checkint`, `lr_toint`, `lr_fx_checkint` accepting 2^63 | REMOVED (item 4 commit) | Accepted the non-integer 2^63 only so that `math.maxinteger` (which rounds to 2^63, `gaps/no-int64.eigs`) stayed usable. Now `x >= 2^63` has no integer representation, as in lvm.c `luaV_flttointns`; uses of maxinteger diverge (no-int64). |
| 6 | parse.eigs keying `_ENV` and debug-upvalue support on source tokens | REMOVED (item 3 (m) commit) | Not an EigenScript limit but a performance dodge that made semantics depend on spelling (`debug["get".."upvalue"]`). Every chunk now has a real `_ENV` upvalue and inspectable closures. |
| 7 | `elseif` -> `elif` | KEPT | The natural translation of an elseif chain. |
| 8 | elseif whose condition hoists statements nests under `else:` | KEPT | The natural translation: hoisted statements must run only when earlier conditions failed. |
| 9 | `lr_gget`/`lr_gset` (globals of the main chunk index `lr_G`) | KEPT, then subsumed | They are `lr_index of [lr_G, ...]`, no limit dodged; after (m) every global goes through the `_ENV` variable anyway. |
| 10 | `em_numlit` writing a non-round-tripping double as `f64_from_bytes` | KEPT | The value is an ordinary double, representable in EigenScript; this is the exact literal, nothing diverging is hidden. |
| 11 | `em_nulstr` (`str_from_bytes`) | KEPT | Already the direct translation; rows diverge at the NUL (`nul-in-string`). |
| 12 | coroutine resume depth 200, `__index` chain 2000, pattern depth 200, 200 locals, 255 upvalues | KEPT | Lua's own limits (LUAI_MAXCCALLS, MAXTAGLOOP, MAXCCALLS, MAXVARS, MAXUPVAL), not EigenScript's. |
| 13 | xoshiro256** state as [hi, lo] 32-bit pairs | KEPT | Internal generator state, not a Lua value; it is lmathlib.c's own `Rand64` fallback shape. Results that are full 64-bit integers still diverge (no-int64). |
| 14 | `lr_intdigits` big-integer printing | KEPT | Prints a double's exact decimal value, as `%d` of the integer would; no limit dodged. |

The three removals that dodged EigenScript limits changed no row's verdict. No graded row reaches those limits. The
gaps now surface where a program reaches them; each has a reproducer and a LEDGER row: `list-literal-cap`,
`expr-nesting`, `subscript-nesting`.

## Item 3: reviewer findings

| finding | result | D row |
|---|---|---|
| (a) repeat-until closes x before cond | FIXED: the condition is evaluated inside the body's `<close>` regions | `tbc_repeat_until.lua` |
| (b) generic-for 4th value never closed | FIXED: explist adjusted to 4; checked ("variable '(for state)' got a non-closable value") and closed on exit, break, return, error | `tbc_genfor_close.lua` |
| (c) `io.read(2)` consumes the line | FIXED (reproduced on a file and a pipe: ref `ab`/`cdef`, cand `ab`/`line2`): one persistent stdin buffer, liolib's read_line/read_chars/read_number/test_eof. The grader's stdin is empty, so the D row covers end-of-input behaviour (`io.read(0)` was `""`, now `nil`) | `io_read_eof.lua` |
| (d) `__close` yields during `coroutine.close` | FIXED: closing runs non-yieldable; yield errors also lost their position | `co_close_yield.lua` |
| (e) `isyieldable` true in a gsub callback | FIXED: false while a non-continuation C call runs | `co_isyieldable_c.lua` |
| (f) `%z` matched "z" | FIXED (reproduced: ref `nil`, cand `z`): `%z` is the NUL class | `str_class_z.lua` |
| (g) `io.output(io.stderr)` ignored | FIXED: default input/output files | `io_default_output.lua` |
| (h) `rawget(io.stdout, "x")` passed | FIXED (reproduced): rawget/rawset/rawlen/next/setmetatable reject file handles; ltablib's checktab needs `__index`/`__newindex`/`__len` per function | `io_file_results.lua` |
| (i) table.move with `__eq` | REFUTED by the critic; nothing done | |
| (j) `load("#x\nreturn 1")` compiled | FIXED (reproduced): the `#` line skip moved from the lexer to file loading | `load_shebang.lua` |
| (k) `package.searchers` unsupported | FIXED: require walks `package.searchers`; preload, Lua files, and both C searchers (finding a C library is UNSUPPORTED) | `require_searchers.lua` |
| (l) flush returns the handle | FIXED (reproduced): returns `true` | `io_file_results.lua` |
| (m) `debug["get".."upvalue"]` returns nil | FIXED: every compiled function answers an upvalue query, and `_ENV` is always a real upvalue. Nothing depends on source tokens. A registry approach was tried first and dropped: it made closure creation 10x slower. The query costs about 15% per call. | `debug_upvalue_computed.lua` |

## Item 4: critic's bugs

| bug | result | D row |
|---|---|---|
| `getinfo(2)` in `__close` during unwinding | FIXED: the unwinding close is called from C (site 0); coroutine.lua:238 passes | `tbc_unwind_frame.lua` |
| global assignment in a parenthesized loaded call | NOT-REPRODUCED: the reproducer prints `0:10 1:10 14:10 20:10` from both the reference and the candidate, both before and after removing the `lr_genv` shim. It also matched with `_ENV`/debug tokens present, inside a function, via nested `load`, and for L up to 190. | |
| `%f` frontier / gmatch empty matches | FIXED where it reproduced: frontier tests at the end of the subject (`%f[%z]`, `%f[%Z]`, `%f[^%z]`) gave count 0 on 6e6aafe, fixed by (f). The quoted `aaa| bbb|` gmatch case already matched on 6e6aafe. | `str_frontier_end.lua` |
| gsub replacement false/boolean | NOT-REPRODUCED: 12 probes (table and function replacements returning false, true, nil, a table, numbers; bad `%` escapes) give identical output and messages | |
| numeric for with string bounds | FIXED: strings convert and make a float loop; checks are in lvm.c order. The loop variable prints `10` rather than `10.0` (float subtype gap), so the D row prints with `%d` | `for_string_bounds.lua` |
| `table.remove({[0]="ban"})` | FIXED: ltablib tremove/tinsert | `tbl_remove_insert.lua` |
| `__len` non-integer in table.insert | FIXED: luaL_len semantics in insert/remove/concat/unpack/sort | `tbl_len_nonint.lua` |
| for near maxinteger | EigenScript gap: both bounds are the double 2^63, so a float loop whose step is absorbed. Reproducer `gaps/int64-for-count.eigs` | |
| lexer messages | FIXED: escapes and their near-text, long string/comment "(starting at line N)", `near <eof>`, invalid long string delimiter, read_numeral | `lex_error_messages.lua` |
| integer-conversion errors | FIXED: [-2^63, 2^63) only (inventory #5) | `int_conversion_errors.lua` |

## Item 5: peel, and the bugs it found

Every S row was run to its first failure, the line blanked in a scratch copy, and run again, up to ten failures.
LEDGER.md has each row's ten failures with their classes. The peel found five more front-end bugs, all fixed with
D rows:
- `unpack("i7")` sign (tpack.lua:63): `str_unpack_signext.lua`.
- `"\n\r"` counted as two lines (literals.lua:252): `lex_line_endings.lua`.
- `__len` got one argument (events.lua:180): `meta_len_args.lua`.
- `debug.setmetatable` on non-tables (events.lua:464): `meta_type_metatables.lua`.
- `getinfo(print)` said Lua (db.lua:38): `debug_getinfo_func.lua`.

After these fixes, some rows run to their end once the gap lines are blanked: events, cstack, gengc, coroutine,
literals, locals, utf8 (with NUL removed) and verybig. constructs.lua also runs to its end, but takes 469 s.

**LEDGER counts by class (first failure):**

| class | S | D |
|---|---|---|
| EigenScript gap | 15 | 12 |
| out of scope | 6 | 0 |
| front-end bug (open) | 0 | 0 |
| unspecified | 0 | 0 |
| PASS/MATCH | 2 | 63 |

Behind first failures:
- literals.lua:225-228 is classed `unspecified`: `%p` identity of equal long strings.
- constructs.lua has an open front-end limitation, speed. With its out-of-scope line blanked, every assert passes,
  but about 200000 `load`s at about 1 ms each take 469 s.

Removed claims: round 2 said that every library function was called with 40 argument shapes, and that every
message was identical. Neither was re-established, so both are gone. coroutine.lua:238 was filed as out of scope;
it is a front-end bug, now fixed.

## CAVEATS

- Peeling blanks lines, and blanking a helper line hides later checks. Where that mattered, the caller was blanked
  instead: sort, literals, pm, utf8 and nextvar. Classification still stops at ten failures per row, so later
  failures are unclassified.
- (c): the D row covers only end-of-input reads, because the grader's stdin is empty. Partial reads were checked by
  hand against the reference on a regular file and on a pipe. On a pipe, EigenScript's `read_line` drops `"\r"` before
  `"\n"` and cannot tell whether the last line had a newline. That is an EigenScript limitation and has no
  reproducer yet. A regular file is read byte for byte.
- `debug.getinfo(f)` now reports `linedefined`/`lastlinedefined` for function values. `source` is still
  `"@" .. short_src`, which is wrong for string chunks; it is out of scope.
- Normal-path `__close`: `getinfo(2).currentline` reports the declaration line, while Lua reports the closing
  statement's line. Not fixed; no graded row checks it.
- The upvalue query adds a type check to every Lua function call, about 15% on a call-heavy loop.
- `math.maxinteger` no longer passes integer argument checks (inventory #5). Rows that use it fail earlier and with
  a different message than in round 2 (sort.lua count 21 -> 14, nextvar 211 -> 210). The class is unchanged (no-int64).
- The NOT-REPRODUCED verdicts depend on how the reproducers were quoted in the brief. The critic's exact harness was
  not available.
