# EigenLua front end: divergence ledger (round 2)

Every row of `tools/grade.sh --candidate bin/eigenlua --tier all` that is not PASS/MATCH, classified.

- **Runtime:** EigenScript `main` at `686d3b7d14837efb7e6e2b55882190d1dd20a332` (EigenScript#1647, with the real
  `bool`). Its `--version` still prints `0.44.0`; `bin/eigenlua` checks for the bool type instead.
- **Reference:** PUC-Rio Lua 5.4.9 from `tools/build_ref.sh`.
- **Grader verdict, end of round 2:**
  `SUMMARY S=2/23 D=40/52 fail=17 diverge=12 hang=1 crash=0 unsupported=3 examined=75 assert=trusted`.
- **Before this round** (round 1, on v0.44.0): `SUMMARY S=0/23 D=13/47 fail=23 diverge=12 hang=0 crash=0 unsupported=22
  examined=70 assert=untrusted`.

Tier D has 52 rows, not 47. Round 2 added five programs for EigenLua#5, one per bug. All five MATCH.

## Classes

| class | meaning |
|---|---|
| `front-end bug` | Fixed here. None is open: every one found is in the list at the end. |
| `EigenScript gap` | The direct value mapping (owner decision 1) meets something EigenScript cannot represent or do. Each has a reproducer under `gaps/`, with its output on 686d3b7d. |
| `unsupported` | The front end does not implement it. This round, every such row stops in a region GAPS.md declares **out of scope**: most of `debug`, `collectgarbage` counts, and `io` beyond print/write/stdin. |
| `unspecified` | Behaviour the manual leaves open. No row is in this class. |

## Counts

| class | rows | S | D |
|---|---|---|---|
| EigenScript gap | 27 | 15 | 12 |
| unsupported (out of scope) | 6 | 6 | 0 |
| front-end bug | 0 | 0 | 0 |
| unspecified | 0 | 0 | 0 |
| unclassified | 0 | 0 | 0 |
| PASS / MATCH | 42 | 2 | 40 |

## Gap reproducers

Each is run as `eigenscript gaps/<file>`. This is its stdout on 686d3b7d.

| file | gap | stdout | rows it explains |
|---|---|---|---|
| `no-int64.eigs` | No 64-bit integer, so values past 2^53 round and nothing wraps. | `9007199254740992` / `9.223372036854776e+18` / `true` | D: int_maxinteger, int_past53, int_wrap, rng_xoshiro. S: bitwise, locals, math, nextvar, sort. |
| `no-float-subtype.eigs` | One number type, so 1.0 cannot be told from 1. | `1` / `1` / `3` / `9007199254740992` / `true` | D: int_one_vs_one, ops_matrix, str_format_num. |
| `no-nonfinite.eigs` | No inf/nan. Overflow saturates at 1e308, and x/0 raises. | `1e+308` / `division by zero` | D: num_print. S: events. |
| `nul-in-string.eigs` | Strings are NUL-terminated. | `1` / `chr of 0: strings are NUL-terminated ...` | D: str_byte_char_sub_rep, str_embedded_nul, str_len, utf8_lib. S: literals, pm, strings, tpack, utf8. |
| `call-depth.eigs` | About 5000 VM frames, against Lua's 200000 levels. | `{"kind": "limit", "message": "call stack overflow", "line": 13}` | S: calls (line 162), cstack (its first overflow test). |
| `no-tail-calls.eigs` | No proper tail calls. | `{"kind": "limit", "message": "call stack overflow", "line": 13}` | S: calls (line 119). |
| `no-weak-refs.eigs` | No weak references and no finalizers. | `[{"x": 1}]` (and `eigenscript --api` lists no weak/finalizer builtin) | S: closure (HANG), gengc. |
| `task-limit.eigs` | At most 255 live tasks; EigenLua runs each coroutine as one. | `task_spawn: too many live tasks (max 255)` / `255` | S: cstack (line 105). |
| `nesting-limits.eigs` | 64 indentation levels and 128 compile-nesting levels, against Lua's ~200. | `eval: parse error in code string` / `eval: compile error in code string` | None graded. errors.lua line 655/656 would hit it after its out-of-scope region. |
| `subscript-nesting.eigs` | Each subscript in one expression leaks a nesting level. | `300` / `eval: parse error in code string` | None graded. Found through errors.lua's register-limit test. |

**Closed:** `gaps/no-boolean.eigs` is deleted. EigenScript#1647's `bool` closed that gap, and Lua booleans now map to
EigenScript bools.

## Tier S (23 rows)

The assert-trust probe matches the reference, so every row runs (`assert=trusted`), and every row's negative control
fails correctly. "Line" is the first failure. Each was found by running the candidate on the unmodified file in the
suite directory.

| row | verdict | count (ref) | class | line | cause |
|---|---|---|---|---|---|
| bitwise.lua | FAIL | 3 (1326) | EigenScript gap | 18 | `0xFFFFFFFFFFFFFFFF` must wrap to -1 (`no-int64`). With each failing assert blanked, its 9 failures (18, 20-22, 53, 72-74, 241) are all int64, and the file then runs to the end. |
| calls.lua | FAIL | 28 (20114) | EigenScript gap | 119 | `deep(30000)` is a tail call, and there are no proper tail calls (`no-tail-calls`). Next is line 162, a deliberate overflow (`call-depth`). |
| closure.lua | HANG | none | EigenScript gap | 37 | `while x[1] do` waits for a weak table entry to be collected (`no-weak-refs`). |
| constructs.lua | FAIL | 5374 (209484) | unsupported (out of scope) | 306 | `debug.getinfo(1, "n").name` is out of scope ("getinfo beyond currentline/short_src"). The rest of the file then compiles about 100000 chunks with `load`, which would exceed its 30 s budget for a compiler written in EigenScript. |
| coroutine.lua | FAIL | 83 (309) | unsupported (out of scope) | 238 | `debug.getinfo(2).what` from a `__close` run during unwinding (Lua: `"C"`). After that, `debug.sethook` (349) and `getlocal`/`setlocal` (637). |
| cstack.lua | FAIL | 261 (1206) | EigenScript gap | 105 | 1000 coroutines suspended at once exceed 255 tasks (`task-limit`). |
| db.lua | UNSUPPORTED | 0 | unsupported (out of scope) | 16 | `debug.gethook` (hooks). |
| errors.lua | UNSUPPORTED | 88 (295) | unsupported (out of scope) | 239 | `debug.setuservalue` on a light userdata. In a scratch copy with the out-of-scope regions removed, every message check matches except the "error in error handling" stack-overflow test at 553 (`call-depth`) and the 100-level `while`/`if` nesting at 655-656 (`nesting-limits`). |
| events.lua | FAIL | 154 (444) | EigenScript gap | 168 | `1/0` (`no-nonfinite`). |
| gc.lua | FAIL | 5010 (5169) | unsupported (out of scope) | 194 | `gcinfo() < x` reads `collectgarbage("count")`, which is out of scope. Later, weak tables (`no-weak-refs`). |
| gengc.lua | FAIL | 18 (19) | EigenScript gap | 122 | A weak entry must be cleared (`no-weak-refs`). |
| goto.lua | **PASS** | 65 | | | |
| literals.lua | FAIL | 1 (877) | EigenScript gap | 11 | `load` of a chunk holding `'a\0a'`: the chunk ends at the NUL (`nul-in-string`). |
| locals.lua | FAIL | 2175 (2735) | EigenScript gap | 88-104 | The `until p <= 0` loop waits for integer overflow. Past 2^53, `a == 2^i` in the loaded chunk (its line 3) fails (`no-int64`). |
| math.lua | FAIL | 3 (floor 21739) | EigenScript gap | 13 | `maxint == minint - 1` (`no-int64`). |
| nextvar.lua | FAIL | 211 (floor 8854) | EigenScript gap | 78 | `ipairs` must wrap maxinteger to mininteger (`no-int64`). |
| pm.lua | FAIL | 4 (395) | EigenScript gap | 27 | `find` in `'a\0o a\0o a\0o'` (`nul-in-string`). |
| sort.lua | FAIL | 21 (258507) | EigenScript gap | 64 | `unpack(t, maxI - 1, maxI)` (`no-int64`). Before this round it hung there: integer loops and `unpack` now count iterations, as Lua does. |
| strings.lua | FAIL | 3 (332) | EigenScript gap | 22 | `'alo\0alo' < 'alo\0b'` (`nul-in-string`). With each failing assert blanked, all 23 failures are NUL, float-subtype or inf. |
| tpack.lua | FAIL | 6 (471) | EigenScript gap | 51 | `pack("h", -0x8000)` holds a zero byte (`nul-in-string`). Later, hex literals past 2^63 (`no-int64`). |
| utf8.lua | FAIL | 61 (1193) | EigenScript gap | 57 | `utf8.charpattern` holds a NUL, so the pattern is cut (`nul-in-string`). |
| vararg.lua | **PASS** | 80 | | | |
| verybig.lua | UNSUPPORTED | 5 | unsupported (out of scope) | 141 | `os.tmpname`/`io.open` (file I/O). |

## Tier D: DIVERGE (12 rows)

Each row's stdout was diffed line by line against the reference. For ops_matrix, all 1099 differing lines were checked
mechanically: operands 10/11 (maxinteger/mininteger) are int64; operands 7/8/16 (0.0, -0.0, "1e1") are float subtype;
inf/nan results are non-finite. Nothing else differs.

| row | first difference | class | evidence |
|---|---|---|---|
| int_maxinteger.lua | line 1 `9223372036854775807` vs `9.2233720368548e+18` | EigenScript gap | `no-int64`: maxinteger maps to 2^63. |
| int_one_vs_one.lua | line 2 `1.0` vs `1` | EigenScript gap | `no-float-subtype` |
| int_past53.lua | line 2 `9007199254740993` vs `...992` | EigenScript gap | `no-int64` (line 5 is the float subtype) |
| int_wrap.lua | line 1 mininteger vs `9.2233720368548e+18` | EigenScript gap | `no-int64`: no wrap |
| num_print.lua | line 1 (nothing printed) | EigenScript gap | `no-nonfinite`: its value table holds `1/0`, which raises |
| ops_matrix.lua | line 24 `float -0` vs `integer 0` | EigenScript gap | `no-float-subtype`, `no-int64`, `no-nonfinite` (all 1099 lines, see above) |
| rng_xoshiro.lua | line 3 `math.random(0)` | EigenScript gap | `no-int64`. The generator is bit-exact: every float, every ranged integer and the seeds match. Only full 64-bit integers past 2^53 round. |
| str_byte_char_sub_rep.lua | line 1 `65 0 200` vs `65 nil` | EigenScript gap | `nul-in-string`: `string.char(65, 0, 200)` ends at the NUL |
| str_embedded_nul.lua | line 1 `4` vs `1` | EigenScript gap | `nul-in-string` |
| str_format_num.lua | line 11 `1 1.0` vs `1 1` | EigenScript gap | `no-float-subtype` (`%s` of 1.0). The 10 lines before it match. |
| str_len.lua | line 3 `3` vs `1` | EigenScript gap | `nul-in-string` |
| utf8_lib.lua | line 9 `utf8.charpattern` bytes | EigenScript gap | `nul-in-string`. Lines 1-8 (char, codepoint, len, offset, codes) match. |

The five EigenLua#5 rows each diverged before their fix and match after it:

| row | bug | before (commit) | after |
|---|---|---|---|
| err_method_nil.lua | (a) a nil receiver in `o:m()` named the method | DIVERGE line 1 `ref=false 14: attempt to index a nil value (upvalue 's')` `cand=... (method 'foo')` (b7b8c10) | MATCH |
| str_nul_lazy.lua | (b) a NUL literal was evaluated eagerly by `and`/`or` | UNSUPPORTED rc=3: the round-1 refusal exits before printing, so this row cannot show a DIVERGE (b7b8c10) | MATCH |
| multi_assign_order.lua | (c) surplus right-hand expressions were evaluated first | DIVERGE line 1 `ref=first first,second cand=first second,first` (b7b8c10) | MATCH |
| method_lookup_order.lua | (d) `o:m(args)` evaluated args before looking up `o.m` | DIVERGE line 1 `ref=lookup m,arg1,arg2,call m 2 cand=arg1,arg2,lookup m,call m 2` (b7b8c10) | MATCH |
| break_outside_loop.lua | (e) `break` outside a loop reported its own line | DIVERGE line 3 `ref=3 nil c:7: break outside loop at line 3 cand=3 nil c:3: ...` (74e9ee1) | MATCH |

## What remains UNSUPPORTED (exit 3)

- **debug:** `sethook`/`gethook`, `getlocal`/`setlocal`, `getregistry`, `getuservalue`/`setuservalue`, `upvaluejoin`,
  `setcstacklimit`, `debug.debug`, and `getinfo` fields beyond `currentline`/`short_src`/`source`/`what` (`name`,
  `linedefined`, `func`, ...). All are out of scope (GAPS.md).
- **Files and processes:** `io.open`, `io.popen`, `io.tmpfile`, `io.close`, `io.lines` with a file name, `os.tmpname`,
  `os.remove`, `os.rename`, `os.execute`, `os.date`, and `os.time` with a table. These are out of scope ("io beyond
  print, io.write and stdin reads").
- **Other:** `string.dump` and binary chunks (out of scope); `package.loadlib` (C modules, out of scope); `loadfile`
  from stdin.
- `debug.getinfo` of another coroutine.
- A to-be-closed variable in a block that also holds goto labels. The dispatch loop would split its scope. No graded
  row has one.

## Front-end bugs found and fixed this round

No graded row in round 1 exercised these. Each was checked against the reference.

- **EigenLua#5 (a)-(e).** See the table above.
- **The bool runtime.**
  - `throw of` a list whose second element is a bool is refused by the new VM, so errors are now thrown as a dict.
  - Functions compare by identity.
- **Soft keywords.** `prev is x` or `where is x` as the last statement of a block is an EigenScript question, not an
  assignment.
  - The `%f` frontier pattern read its previous character as 0.
  - `collectgarbage`'s first mode switch returned nil.
  - Every such variable is renamed.
- **Coercion and shifts.**
  - Bitwise operators coerced strings. Lua 5.4 does not, because its string metamethods cover arithmetic only.
  - A logical right shift of a negative number had the wrong sign.
  - mininteger printed as a float.
- **xpcall.**
  - An error in the handler escaped xpcall. It is now handled again until "error in error handling".
  - The handler ran after unwinding instead of at the error point.
- **Coroutines.** Yields inside C-library callbacks were allowed. They now raise "attempt to yield across a C-call
  boundary".
- **Parser.**
  - Lexical errors were raised before earlier syntax errors.
  - "near" showed a numeral's value instead of its text.
  - The message said `'eof'` instead of `<eof>`.
  - The parameter-list message was wrong.
  - A token after `return` was reported by the wrong rule.
  - A non-assignable target was reported late.
  - There were no nesting, local-variable, register or upvalue limits.
  - `elseif` chains nested one EigenScript level per branch, and deep expressions overflowed EigenScript's nesting.
- **Library.** Argument checks and messages for about 30 functions now follow lbaselib, lmathlib, lstrlib and ltablib
  5.4.9:
  - `math.max`/`min` compare with `lua_compare`, as 5.4.9 does.
  - `string.rep` has a size limit.
  - `pairs` of a non-table returns `next`.
  - `load` accepts number chunks.
  - Error messages use the metamethod name (`metamethod 'add'`) and `__name`.
  - The `for iterator` name, the `'for'` messages, and the integer `//` by zero message.
- **Loops.** Integer `for` loops and `table.unpack` stepped a double, so they hung near 2^63. They now count, as
  lvm.c does.

**How these were found**
- All 12090 substrings of gc.lua's program were loaded and compared with the reference. Every message is identical.
- Every library function was called with 40 argument shapes. The only remaining differences are the float-subtype,
  NUL and inf/nan gaps.
- Every differing line of the DIVERGE rows was classified.
- Several S files were run with each failing one-line assert blanked, in scratch copies only.
