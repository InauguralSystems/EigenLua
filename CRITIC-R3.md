# CRITIC R3 — EigenLua `frontend/r2` @ 5f2722f (PR #6)

Runtime: EigenScript 686d3b7d (built from source), reference PUC-Rio 5.4.9 via `tools/build_ref.sh`.
Round-2 head 6e6aafe checked out in a scratch worktree (`/tmp/r2`). All oracles below were run by me.

## 0. Grader re-run
`tools/grade.sh --candidate bin/eigenlua --tier all` at 5f2722f:
`SUMMARY S=2/23 D=63/75 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=98 assert=trusted` — **matches the claim**.

## 1. New D rows: diverge-before / match-after
My harness: stdout + rc byte-compared against `.ref/bin/lua`, stdin empty (as the grader).
All 23 (not just 10) checked.

| row | 6e6aafe | 5f2722f |
|---|---|---|
| tbc_repeat_until | DIVERGE | MATCH |
| tbc_genfor_close | DIVERGE | MATCH |
| co_close_yield | DIVERGE | MATCH |
| co_isyieldable_c | DIVERGE | MATCH |
| io_default_output | DIVERGE | MATCH |
| io_read_eof | DIVERGE | MATCH |
| io_file_results | DIVERGE | MATCH |
| str_class_z | DIVERGE | MATCH |
| load_shebang | DIVERGE | MATCH |
| require_searchers | DIVERGE | MATCH |
| debug_upvalue_computed | DIVERGE | MATCH |
| tbc_unwind_frame | DIVERGE | MATCH |
| for_string_bounds | DIVERGE | MATCH |
| tbl_remove_insert | DIVERGE | MATCH |
| tbl_len_nonint | DIVERGE | MATCH |
| lex_error_messages | DIVERGE | MATCH |
| int_conversion_errors | DIVERGE | MATCH |
| str_frontier_end | DIVERGE | MATCH |
| str_unpack_signext | DIVERGE | MATCH |
| lex_line_endings | DIVERGE | MATCH |
| meta_len_args | DIVERGE | MATCH |
| meta_type_metatables | DIVERGE | MATCH |
| debug_getinfo_func | DIVERGE | MATCH |

(require_searchers and meta_type_metatables were UNSUPPORTED rc=3 at 6e6aafe, i.e. also not matching.) **PASS: every new row proves its fix.**

## 7. Grader untouched
`git diff origin/main..frontend/r2 --stat -- tools tests corpus`: only `A` files under `corpus/D/`, `corpus/D.manifest`
(additions only, no `-` lines), and `tests/parse_all.sh` (comment + `47`→`75` in the population check). `tools/` untouched. **PASS.**

## VERDICT
**FAIL (narrowly).** The grader numbers, all 23 new D rows, both NOT-REPRODUCED verdicts, the shim removals, and the grader-untouched rule all hold up under my own checks. But the ledger's claim "front-end bug (open): 0" is false. The peel stopped at ten failures per row and missed in-scope front-end bugs behind the I64/OOS first failures in two graded S rows:

1. **`table.sort` is a merge sort, not ltablib's `auxsort`** (`src/runtime.eigs:1631-1673`). It never raises `invalid order function for sorting` (sort.lua:201-208) or `array too big` (sort.lua:199). Its comparator call order, its `__index`/`__newindex` read/write order, and its compare-error operand order all differ from 5.4.9. This is not an EigenScript limit: auxsort is plain index arithmetic. It is also a non-direct translation, which rule 1 forbids. The source comment defends the swap on stability grounds and never mentions the error checks the S row tests.
2. **`debug.traceback` does not skip middle levels** (luaL_traceback's LEVELS1=10/LEVELS2=11 `...\t(skipping N levels)`), and unnamed Lua functions print `in function <?>` instead of `in function <file:line>`. In errors.lua:525-529 the `while stack[i] ~= l1 do assert(...)` loop then runs about 2000 times instead of about 20. With the OOS and CD lines blanked, the same copy gives **ref 275 asserts and candidate 2453**. The ledger says errors.lua "runs to the end", but its count would never match. The skip logic depends only on the level count, so it is in scope (GAPS.md puts only getinfo names and similar debug features out of scope).

## LARGEST ACTIONABLE GAP: table.sort (runtime library layer, `src/runtime.eigs` lr_t_sort/lr_msort)
Reproducer (sort.lua:12-16 + 200-208, verbatim):
```lua
local function checkerror (msg, f, ...)
  local s, err = pcall(f, ...)
  assert(not s and string.find(err, msg))
end
local function check (t)
  local function f(a, b) assert(a and b); return true end
  checkerror("invalid order function", table.sort, t, f)
end
check{1,2,3,4}
check{1,2,3,4,5}
print("reached end")
```
- ref: `reached end`, rc 0
- 5f2722f (and 6e6aafe): `sort204.lua:3: assertion failed!`, rc 1. Shorter form: `print(pcall(table.sort,{1,2,3,4},function() return true end))` gives ref `false invalid order function for sorting` and candidate `true`.

Also: `__len` returning `1<<31` gives ref `bad argument #1 to 'table.sort' (array too big)`, candidate `true`. On a 3-element proxy the reference reads and writes `r1 r3 w1=2 w3=3 r2 r1 w2=2 w1=1` and the candidate `r1 r2 r3 w1=1 w2=2 w3=3`. `pcall(table.sort,{3,1,"a",2})` gives ref `attempt to compare string with number`, candidate `... number with string`.
Fix: port ltablib.c `auxsort`/`partition`/`choosePivot` with lua_geti/lua_seti order. Add a D row.

## Other findings
| # | finding | layer | severity |
|---|---|---|---|
| B | debug.traceback: no level skipping, `<?>` instead of `<file:line>` (repro: `local function r(n) if n==0 then return debug.traceback("m") end return (r(n-1)) end; print(r(40))` gives ref 24 lines and candidate 45). Makes errors.lua's count 2453 vs 275 on the same peeled copy. | runtime (debug lib) | blocking for the ledger's honesty |
| C | `os.exit("bad")` / `os.exit({})` exits rc 0 instead of raising `bad argument #1 to 'os.exit' (number expected, got string)`; `pcall(os.exit,"bad")` kills the program. Already present at 6e6aafe. | runtime (`lr_os_exit`, no luaL_optinteger) | minor |
| D | `arg` global missing: `print(#arg, arg[0])` gives ref `0 prog.lua` and candidate `attempt to get length of a nil value (global 'arg')`. lua.c's createargtable; GAPS.md does not exclude it. | runtime/driver | minor |
| E | No C-stack (LUAI_MAXCCALLS) count for metamethod recursion: `t=setmetatable({}, {__index=function(t,k) return t[k+1] end}); pcall(function() return t[1] end)` gives ref `C stack overflow` at depth 196 and candidate `EigenScript limit error: call stack overflow` at depth 817. Lua's limit is below EigenScript's, so the front end could reproduce it. (cstack.lua only checks the substring "stack overflow", so no row changes.) | runtime | minor |
| F | `gaps/call-depth.eigs` says about 2 VM frames per Lua call, so about 2000 levels. I measured 1363 Lua levels (about 3.7 frames per call). | ledger text | cosmetic |
| G | An EigenScript NaN in `^` (`(-8)^(1/3)`) prints `lua: EigenScript value error: pow: ...` with no `prog.lua:N:`, so rule 4 is not met. The nonfinite gap is real; the missing location is not. | runtime error wrapping | minor |

## 2. NOT-REPRODUCED re-checks (my own harnesses)
- **Parenthesized global assignment**: the form `a=1; load("return "..e)()` with L = 0, 1, 14, 15, 16, 17, 20, 30, 60 prints `L:10` for every L on ref, 5f2722f and 6e6aafe. The same holds for the `local x = e return a` chunk form, a plain source file (L = 0, 1, 14-17, 20, 40, each with a `local function g()` variant), and inside a function (L=18). All MATCH. **Confirmed NOT-REPRODUCED.**
- **gsub false/boolean replacement**: 23 probes (function returning false/nil/true/mixed, table with false/true/number, `__index` table, empty pattern, `%2`, trailing `%`, `%%`, table/function returning a table, replacement false/true/number, n=-1/1.5/"2", position captures) all MATCH, messages included. **Confirmed NOT-REPRODUCED.**

## 3. Shim removal
- #1/#2: `grep lr_genv\|lr_gsetenv\|lr_cell0 src/` returns nothing. Loaded chunks use `lr_index of [ENV[0],...]`. Gone.
- #3: `em_listlit` (emit.eigs:400) is a single `[...]` literal. Gone.
- #4: no hoist-every-16 logic left in em_expr (comment at emit.eigs:449-451). errors.lua:639 now fails with an unlocated `Parse error line 9: expression nesting too deep` from EigenScript, as the rule requires.
- #5: `lr_checkint` (runtime.eigs:1104) rejects `x >= 2^63`. Gone.
- #6: every compiled function begins `if type of A == "dict": return [U,...]` (upvalue query). Not token-keyed. Gone.
- Kept #7-#14: reviewed. Natural translations. `elif` (#7) is natural even though the comment cites EigenScript's 64-level nesting cap.
- **Missed by the inventory**: `table.sort` swapped for a merge sort (finding A). This is not a limit dodge but a substitute algorithm that changes observable behaviour. No other dodge found: I grepped for hoist/split/chunk/limit/stand-in.

## 4. Ledger peel (my own; 5 rows + 3 "runs to end" checks)
| row | ledger class | my peel | agrees? |
|---|---|---|---|
| db.lua | OOS | 16 gethook (OOS), 33, 34 getinfo option validation, 42 (`b.func == test` false, activelines nil), 43-48 C/OOS | yes. OOS under GAPS.md ("getinfo beyond currentline/short_src"); `func` identity is borderline |
| errors.lua | OOS | 239 setuservalue (OOS), 280/287 string.dump (OOS), 553/557 CD, 639 NEST. Then rc 0, **but count 2453 vs ref 275 on the same copy** (traceback, finding B) | **no**: an in-scope bug is hidden |
| gc.lua | OOS | 194 gcinfo, 201 step | yes |
| strings.lua | gap | 22, 23, 24, 25, 27, 29, 30, 33 NUL; 51 I64 (`sub(…, mini, maxi)`); 53 NUL | yes |
| calls.lua | gap | 119 TC; 111/120 C; 122 TC; 123 C; 187/176 TC; 313 NUL; 314 OOS (`getinfo(a).source`); 331 OOS; 332 C | yes |
| sort.lua (extra) | gap (10 × I64) | behind them, 199 and 204-208 are front-end (finding A) | **no**: unclassified in-scope bug |
| events (168 blanked) | runs to end | ref 436 / cand 436 | yes |
| coroutine (349, 352-355, 417 blanked) | runs to end | 301 / 301 | yes |
| gengc (122 blanked) | runs to end | ref 18 / cand 17: the one missing assert sits in a `__gc` finalizer (WK) | yes, though "runs to end" hides the count |

## 5. Regressions
- **2^63 rejection**: at 5f2722f `("hello"):sub(2, math.maxinteger)`, `string.find(s,p,maxinteger)`, `string.byte(s,1,maxinteger)`, `select(maxinteger,…)`, `string.format("%d",maxinteger)`, `math.random(maxinteger)` and `math.ult(1,maxinteger)` all raise `number has no integer representation`. 6e6aafe returned the Lua result for the first three. `for i=1,math.maxinteger do … break end` still works. Under rule 2 this is the right translation: maxinteger maps to the double 2^63, a direct mapping, and accepting it was a shim. The cost is that common `sub(i, math.maxinteger)` idioms now error instead of silently working. The error is located (`prog.lua:N:`) and classed I64. **Accept.**
- **Perf** (compiled .eigs only, no compile time, idle machine, 3 runs each):
  - empty-call loop, 3M calls: 6e6aafe 4.59 s, 5f2722f 5.11 s, ratio **1.11**
  - `add(s, id(i))` loop, 2M iterations: 10.97 s vs 11.48 s, ratio **1.05**
  - The builder's "about 15%" is a fair upper bound.

## 6. Fresh programs (25 written; diffed vs ref)
MATCH: errmsg (30 error-message probes), multret/pcall/select/table.pack, varargs with nil holes, closures, strings/patterns (26 lines), pcall/xpcall/coroutine errors, `__tostring`/`__name`/all arithmetic and bitwise metamethods, `__lt`/`__le`/`__eq`/`__concat` mixes, goto (nested blocks, repeat-until continue, label errors), sort with custom comparators (valid order), top-level error rc, `os.exit(true,true)` without a newline.
DIVERGE, already classed: float subtype (`7.5//2` → `3`, `"2"^3` → `8`, `1e15`, `2^24`, `-0.0`); no-nonfinite (`1/-0.0`, `t[0/0]`, fmod(1.0,0) → nan); NUL (`%q` of `\0`); I64 (maxinteger loops hang, `math.abs(mininteger)`); border of `{1,nil,3}` (unspecified); TBC+label UNSUPPORTED (declared).
DIVERGE, new: table.sort (A), traceback (B), os.exit (C), `arg` (D), metamethod C-stack (E), unlocated NaN error (G).

## OUT OF SCOPE (not judged)
- I did not re-run constructs.lua's 469 s claim.
- I did not re-peel bitwise, closure, cstack, literals, locals, math, nextvar, pm, tpack, utf8 or verybig.
- I did not verify io partial reads on a pipe ((c) caveat).
- `debug.getinfo(f).func` identity and `source` for string chunks are OOS under GAPS.md wording.
