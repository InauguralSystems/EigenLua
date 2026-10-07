# CRITIC R5 — blind critique of frontend/r5 @ 4a906511 (PR #23)

## VERDICT: claims do NOT fully hold — 2 claimed fixes incomplete, 1 shim question for the owner
- **#13 (FAIL, largest gap):** read counts diverge on syntax/semantic-error positions beyond the builder's 13 probes. Errors in a table constructor read one piece too many; `<const>` assignment reads to EOF; `unknown attribute` reads too few.
- **#15 (FAIL, narrow):** hex floats are NOT always correctly rounded. Subnormal results with more than 13 significant hex digits are double-rounded (1 ulp off).
- **#19 (owner decision):** the table.move overflow checks emulate int64 on 32-bit limbs. With a direct double translation the D row HANGs, so its MATCH rests on a workaround of `no-int64`.
- **PASS (ran myself):** #14, #16, #17, #18, #19 behaviour, #20, #12 (claim as stated), #8, #11; all 16 D rows (13 fail at 8a30e385, match at head); #9 perf (+1.44% vs claimed +1.38%); GAPs #10 and closure.lua (no-weak-refs); grader untouched.
- **#7 GAP:** the direction holds, but the report's arithmetic is wrong (budget 230 us, not 300; chunks 154 chars, not 230; lexing regression 1.6x).
- **Double free:** 14-line reproducer found. ASan reports a heap-use-after-free, caused by an under-arity call to a 2-param function. No call-depth overflow is needed.


Runtime EigenScript 686d3b7d, reference PUC-Rio 5.4.9 via tools/build_ref.sh.

## 7. Grader untouched — PASS (ran)
`git diff origin/main..frontend/r5 --stat -- tools tests corpus`: tools/ no change; tests/parse_all.sh only 83->99; corpus only 16 added D files + 16 manifest lines; no M/D on existing corpus files.

## 1. D rows — PASS (ran)
At 8a30e385: D=3/16 (builtin_values, lex_near_raw, tbl_library MATCH — coverage/guard rows as claimed), 10 DIVERGE, 1 HANG (tbl_move_overflow), 2 UNSUPPORTED (debug_getinfo_source_close, tbc_goto_labels). At head: D=16/16. All 13 issue rows fail before and match after.

## 2. Claimed fixes beyond their D rows

### #15 tonumber bases — PASS (ran)
n1.lua: 25 strings x bases 2..36 (signs, `+-1`, `- 1`, inner space, `\t..\n`, `\v..\f`, empty, letters case, base errors 1/37/2.5/"8"/16.0/number arg). Only differences: values past 2^53 (`no-int64`) and `"12\0"` (`nul-in-string`). n2/n3 hex floats with exponents: all differences are `no-float-subtype` (0x1p4 -> integer 16), `no-nonfinite` (1e400 -> 1e+308) or `no-int64`; non-integral values (0x1P-4, -0x1p-1074, 0x1.000000000000081p0 %.17g, 0x.1, overflow `0xff..ffp-100`) match.

### #13 load reader — FAIL (read counts) (ran)
Reader errors / yields / nil and non-string pieces / mode / `error(nil)` / `error(table with __tostring)` / xpcall handler over a reader error: l1.lua all match (only a table address differs).
Read counts do NOT match on several syntax-error positions (l2.lua, l3.lua; reader returns 1 or 2 chars per call, `=c` chunkname; columns: chunk size, reads, length):

| program | chunk | ref reads | eigenlua reads |
|---|---|---|---|
| `x = {1,,3}` | 1 | 9 | 10 |
| `x = {,}` | 1 / 2 | 7 / 4 | 8 / 5 |
| `x = {a=1,,}` | 1 / 2 | 11 / 6 | 12 / 7 |
| `x = {1;;2}` | 1 | 9 | 10 |
| `x = {1,2,,3}` | 1 | 11 | 12 |
| `local x <const> = 1; x = 2` | 1/2/3/7 | 25/13/9/4 | 27/14/10/5 (reads to EOF) |
| `local x <const> = 1\nx = 2\n\n\n\n` | 1 / 2 | 24 / 12 | 30 / 16 (reads to EOF) |
| `local x <const> = 1; function f() x = 2 end\n\n\n` | 1 / 2 | 38 / 19 | 47 / 24 |
| `return function(...) local a <const> = 1; a = ... end\n\n\n` | 1 / 2 | 46 / 23 | 57 / 29 |
| `local x <foo> = 1 \n\n\n` | 1 / 2 | 16 / 8 | 14 / 7 (reads FEWER) |

Messages and lines all match; only the count of reader calls differs. Three distinct causes: (a) errors inside a table constructor read one piece too many; (b) "attempt to assign to const variable" is raised only after the whole chunk is read (lparser.c raises it in restassign/check_readonly, at the `=`); (c) "unknown attribute" is raised before lparser.c's `checknext(ls, '>')` reads the next token. The R5 claim "all 13 read-count probes match" holds for its 13 probes but not in general.

### #14 C-function error positions — PASS (ran)
c1.lua (~80 library functions raising, called directly by pcall) and c2.lua (47 raises from inside a Lua frame: next, sort with bad/erroring comparator, concat, gsub replacement errors, __pairs, ipairs' __index, __len in insert, unpack's __index, coroutine.wrap errors, utf8, pack, `<close>` of a non-closable, error levels, load, require, __call, xpcall/pcall arity, print's __tostring): every position prefix matches. Non-position differences found are listed under probe bugs.

### #16 traceback(thread) — PASS (ran)
tr.lua/tr2.lua: fresh, suspended (levels 0/1/2/99, inside pcall, inside an `__index` metamethod, nested locals), dead by error (levels), finished, normal thread (outer traceback seen from an inner coroutine), running self (levels 0/1), main thread, non-string msg, bad level arg. All frames, skips, `[C]: in function 'coroutine.yield'` lines match. Only differences: calling-code names (`in upvalue 'deep'`, `in local 'g'`, `in metamethod 'index'` vs `in function <tr.lua:N>`), which R4 declared OUT OF SCOPE and which the main-thread traceback lacks too.

### #17 os.exit(code, true) — PASS (ran)
ex1..ex6: closes across nested blocks / a Lua function / a numeric-for body; erroring closes (string and table errors) passing their error to the next; `os.exit` inside a `__close` (nested exit); `os.exit` from inside pcall with pending closes in and outside the pcall; inside a coroutine (coroutine's variables not closed); `os.exit(true,false)`. Output and rc match. (ex5 diverges only because of the pre-existing xpcall-handler/`__close` ordering bug listed under probe bugs.)

(Setup note: `make asan` in /tmp/es replaces src/eigenscript with the ASan+UBSan binary (hard link to build/asan/eigenscript). Probes after 10:27 use build/release/eigenscript (686d3b7d). The full grade, run under both, gives the claimed `SUMMARY S=2/23 D=87/99 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=122 assert=trusted`.)

### #19 table.move — PASS (ran)
mv2.lua: minI..0, minI..-1, minI..minI, minI..-2^62 ("too many elements to move" and the accepted case), empty ranges with any destination, t = -1/minI, e<f with t=minI, f=0 e=-1 t=maxI, -2^53 sources, t=2^63 (float): all match. Targets of maxI-k round to 2^63 and give "number has no integer representation" instead of wrap-around/success: the declared `no-int64` gap. Metamethod sources/targets (`__index`, `__newindex`) and overlapping moves match.

### #20 `<close>` with goto — PASS (ran)
tg.lua/tg2.lua: goto out of three nested loops (numeric for / for / while), goto continue through two nested `do` blocks, backward goto across nested blocks, repeat-until with goto to a label before `until` (and `until` reading a local), goto-loop re-creating a closure, error out of a goto loop, while with continue+break, generic-for goto out, goto in a function returning, an erroring `__close` reached by goto; compile errors "jumps into the scope of local" in do / repeat-until (5 shapes). All match (addresses aside).

### #12 `%p` of a string — PASS on its claim, with a collision caveat (ran)
pp.lua/pp2.lua/pp3.lua/pp4.lua: one string formats alike every time (variable vs literal, empty string, short concatenation); different strings format differently; strings never share an id with a table (both draw on `lr_st.nid`). Long string made by `rep` matches; the declared `no-string-identity` divergence (equal long strings from different places are one id) reproduces.
**Caveat:** functions number from a SEPARATE counter (`function: 0x00000001`, `0x00000002`, ...), so a string's `%p` can equal a live function's `%p`. pp4.lua: string `"some string"` and one of 100 live closures format identically (ref 0, eigenlua 1). The same table-vs-function collision exists at 8a30e385, so the cause is older, but the round-5 string scheme inherits it (at 8a30e385 the djb2 string hash did not collide on pp4). Lua never gives two live objects the same `%p`. Filed below as a probe bug, not a claim failure: the claim is only "same scheme as tables".

### #8 getinfo source + `__close` line — PASS (ran)
gi.lua/gi2.lua: `source`/`short_src`/`what`/line range for text chunks (short, long with comment, multiline function), `=name`, `@file`, plain chunkname, reader chunks, C functions, `@gi.lua` main. `__close` currentline at: do-end, function end with trailing blank line, multi-line return, numeric-for natural end and break, while+break, repeat-until, forward goto out of a block, backward goto, error (-1), if-branch, coroutine body, generic for, nested-if return, return of a tail call, a loaded chunk's main end. All match.

### #11 C-stack per boundary kind + yield/resume — PASS (ran)
cs.lua (16 kinds not all in the D row): `__add`, `__band`, `__newindex`, `__index`, generic-for iterator, sort comparator, xpcall (197), xpcall handler recursion (109), `__close`, gsub with a table `__index`, coroutine.wrap and resume recursion (197, nested error message chains equal), load's reader, table.insert through `__newindex`, pcall+`__index` mix (99), yield inside wrap recursion, and depth restored after recovery. All depths and messages match. `__call` recursion (no C boundary) hits the VM's call depth at 1022 vs Lua's 499990 "stack overflow": declared `call-depth` gap.

### #15 addendum — hex floats: FAIL (ran)
The claim "hex floats are strtod's correctly rounded value" is false for SUBNORMAL results with more than 13 significant hex digits. `lr_hexd` (src/runtime.eigs) rounds once in `m * 256 + r` (to 53 bits) and then again when the division by 2^s lands in the subnormal range: double rounding.
hx.lua: 3000 random 14-23-digit hex numerals around 2^-1074..2^-1022 and 2^900: 4 non-`no-nonfinite` mismatches, all subnormal:

| numeral | ref `%.17g` | eigenlua |
|---|---|---|
| `0x6802b8098be00bbp-1081` | 1.8080571335622205e-308 | 1.808057133562221e-308 |
| `0x45660081b09b0881p-1086` | 6.0319010274445402e-309 | 6.0319010274445352e-309 |
| `0x88e667058008080f089bp-1102` | 1.1898930950400306e-308 | 1.1898930950400301e-308 |
| `0x0080008308838801108fap-1106` | 4.3459152636910326e-311 | 4.3459152636905385e-311 |

Exact check (hx3.lua): `tonumber("0x6802b8098be00bbp-1081") * 2^100` is `0x1.a00ae0262f802p-923` in the reference and `0x1.a00ae0262f804p-923` in eigenlua; the exact rational (Fraction(0x6802b8098be00bb, 2**1081), computed outside the repo) rounds to `0x0.d005701317c01p-1022`, the reference's value. The same numerals as source literals go through the same path. The decimal subnormal `1.8080571335622205e-308` prints identically on both arms, so formatting is not the cause.


## 5. Shims — one candidate (ran)
Grep of the round's `+` lines in src/ for new arithmetic substitutes, limbs, magic constants and stubs. One hit:

**table.move (#19) emulates int64 on 32-bit limbs** (`lr_i64`, `lr_i64add`, `lr_i64neg`, `lr_i64lt`, `lr_i64max`, src/runtime.eigs:1874-1921). ltablib.c's checks `e < LUA_MAXINTEGER + f` and `t <= LUA_MAXINTEGER - n + 1` are int64 arithmetic, and EigenScript has no int64 (`no-int64`). The builder computes them exactly on a two-limb representation instead of translating them directly.
Control: in a scratch copy (/tmp/shim), I replaced the two checks with the direct double translation (`e < lr_maxi + f`, `t <= lr_maxi - (e - f + 1) + 1`, with `lr_maxi = 9223372036854775807`, the value math.maxinteger already maps to). `corpus/D/tbl_move_overflow.lua` then HANGs on its first line (`table.move({}, minI, -1, 1)`: 2^63 + -2^63 = 0, so -1 < 0 passes and n = 2^63). So the row's MATCH comes from the limb emulation, not from a direct translation.
Under owner rule 2 ("where EigenScript cannot represent something, emit the direct translation and let it DIVERGE"), this reads as a workaround of `no-int64`, i.e. a substitute algorithm. The builder's defence is that LUA_MAXINTEGER is a C constant, not a Lua value. **The owner has to decide this one.** If it is a shim, #19's D row should HANG or DIVERGE, and the fix that remains is only "no hang on representable inputs".
Not shims, in my reading: `lr_hexd`/`lex_hexd` (EigenScript's `num of` refuses hex, builtins.c:622, so hand conversion is the only translation available; it is buggy, see #15), `%p` string ids (same scheme as tables), `lr_ccrestore`.

## 3. #9 perf — HOLDS (measured; callgrind via a subagent, release build of 686d3b7d, not ASan)
Loop `local function f(x) return x + 1 end; for i=1,N do s=f(s) end`, N=100000 minus N=0, compiled .eigs run only:

| variant | net instructions |
|---|---|
| head (`if A == null:`) | 2931.79M |
| head, query test deleted | 2890.21M |
| 8a30e385 (`type of A == "dict"`) | 3076.57M |

head vs no-query: **+1.44%** (about 416 instructions per call; claimed +1.38%). A re-run agreed to within 0.01%. head vs 8a30e385: 0.953x (claimed 0.954x). The three compiled programs differ only in the query lines. Nit: the comment at src/emit.eigs:608 says "1.6% of a Lua call, against 6.1%"; the commit and report say 1.38%.

## 4. GAP claims
- **#10 `gaps/pipe-read-line.eigs` — HOLDS (ran).** Both `printf 'a\r\nb'` and `printf 'a\r\nb\n'` print `["a", 1, "b", 1, null]`; the reference reads `#io.read("L")` = 3, then `b`. eigenlua on a pipe gives 2, 2. I also tried the other readers on a pipe: `read_text`, `read_bytes` and `read_bytes_buf` of /dev/stdin give "" / null / null. builtins_host.c `builtin_read_line` strips the `\n` and then the `\r`. A real VM limit.
- **#7 `gaps/vm-op-cost.eigs` — runs as described (ran):** 0.24 us/char, 0.16 us/call, 0.70 us/dict, 16.96 us/eval. The conclusion (VM-floored) holds in direction, and I found no re-lexing, quadratic building or recompiling. But the report's arithmetic is wrong:
  - the budget 20 x 2.3 s / 200000 is **230 us**, not 300 us;
  - constructs.lua makes 204105 loads averaging **154 chars** (GLOB1=0) / 163 (GLOB1=1), not "about 230";
  - the lexing regression was **1.60x** by callgrind (2.79M -> 4.48M -> 2.82M per lex of a 234-char chunk), not 0.34 -> 0.78 ms;
  - the floor (534 us) is a formula with assumed multipliers, not a measurement. On the actual average chunk the same formula gives about 393 us.
  Per-phase timing on a 150-char chunk: lex 0.27, parse 0.34, emit 0.27, eval 0.14 ms, total 1.1 ms (ref 3.9 us).
  One front-end inefficiency: `lr_st.sites` gains about 9 entries per load and is never freed (about 1.8M after the file). In 12000-load runs it coincides with 0.5-1.1 s stalls, which fits the ledger's 2.3 ms/load average against a 1.1 ms steady state. The cause (GC/heap growth) is not proven.
- **closure.lua HANG = no-weak-refs — HOLDS (ran via subagent).** Lines 35-40 (`setmetatable(x, {__mode='kv'})`; `while x[1] do ... end`): the reference leaves after 1861 iterations; eigenlua does 100000 iterations in about 1.5 s with `x[1]` still set. With 37-40 blanked it reaches line 262 (the out-of-scope `upvalueid`) in 0.16 s.

### #18 load mode (not in the brief's list) — PASS (ran)
lm.lua: mode "b" on text and string/reader chunks, `""` mode, "\27" in "t", "\27" after spaces/shebang, empty first piece. All match. Binary chunks are UNSUPPORTED (exit 3), as declared.

## Probe-found bugs BEYOND the claims (do not fail the round; file as issues)
All reproduce against `.ref/bin/lua`. "pre-existing" means the same output at 8a30e385.
1. **xpcall message handler runs AFTER pending `__close` handlers** (pre-existing). Lua runs the handler at the raise point, before unwinding closes. `xpcall(function() local q <close> = setmetatable({}, {__close=function(_,e) print("q",e) end}); error("orig") end, function(m) print("handler",m) return m end)`: ref prints `handler` then `q`; eigenlua prints `q` then `handler`. With `os.exit` inside the `__close`, the handler never runs (ex5.lua).
2. **`%p` / tostring ids: functions use a separate counter from tables and strings** (pre-existing for tables; extends to strings in round 5). `string.format("%p", f) == string.format("%p", {})` or `== string.format("%p", "some string")` can be true for live objects (pp4.lua).
3. **`math.random(2, 1)`**: `bad argument #2` vs ref `#1 ... (interval is empty)` (pre-existing).
4. **`debug.getinfo(1, ">")`** returns a table; ref raises `bad argument #2 to 'debug.getinfo' (invalid option '>')` (pre-existing).
5. **`debug.setupvalue()`**: `bad argument #2 ... (number expected, got no value)` vs ref `#3 ... (value expected)` (pre-existing; ldblib checks arg 3 first).
6. **`dofile("/nonexistent")`**: `cannot open /nonexistent` vs ref `cannot open /nonexistent: No such file or directory` (pre-existing; may be a VM limit if no errno is exposed).
7. **A C function called as a metamethod is named by the indexing expression**: `setmetatable({}, {__index = string.sub}).x` → `bad argument #1 to 'p'` vs ref `'index'` (pre-existing; c2.lua:42).

## 6. The double free (EigenScript#1661) — MINIMAL REPRODUCER FOUND (ran, 686d3b7d)
`/tmp/df/repro.eigs` (14 lines; no try/catch and no call-depth overflow needed):
```
n is {"d": 0}
define g(A, Q) as:
    if Q == 1:
        return 0
    n.d is n.d + 1
    if n.d > 3000:
        return 0
    local args is [A]
    return g of (args)

g of ([1])
n.d is 0
g of ([1])
print of "ok"
```
- Release build (`build/release/eigenscript repro.eigs`): aborts every run with `malloc_consolidate(): unaligned fastbin chunk detected` (rc 134). The variant with try/catch around two overflowing calls (`/tmp/df/m4.eigs`) gives `free(): double free detected in tcache 2` every run.
- ASan (`make asan`, build/asan/eigenscript, `ASAN_OPTIONS=fast_unwind_on_malloc=0`): **heap-use-after-free**.
  - READ at vm.c:890 `slot_as_double` <- vm.c:3601 OP_EQ, i.e. the `Q == 1` test.
  - The freed object is the list `[A]`: allocated by make_list (eigenscript.c:2173) from vm.c:4541, freed by free_value <- val_decref <- gc_cull_value_candidate (eigenscript.c:4793) <- gc_buffer_possible_root <- slot_decref <- env_decref (eigenscript.c:4122) <- vm.c:4365.
- Triggers: a callee with 2 or more params, called UNDER-arity (`g of (args)` with a one-element list binds A = the list and leaves Q unsent), AND the unsent param READ, AND recursion depth >= ~1000 (500 is clean, 1000 crashes). The depth points at the GC possible-root buffer cull, not the call-depth limit.
- Controls, all clean: a 1-param `define g(A)` with the same body (m7); a callee that never reads Q (m6); an inline `g of ([A])` without the local (m1); `Q == null` instead of `Q == 1` (m10; no crash seen).
- Root-cause hypothesis (from reading vm.c:4296-4345): on the fresh-env call path, `param_count > 1 && argc > 0` binds only `min(argc, param_count)` params. The null fill for `[argc, param_count)` runs only `if (can_default)`, i.e. only when the chunk has default params. So an unsent param on a no-default callee is never bound, and reading it sees a stale slot (from a recycled env/slot holding a dead value) that a GC cull has already freed. llms.txt says "under-arity null-fills, silently"; the VM does not do that on this path. EigenLua at head is not affected (1-param entries only); the round-5 builder's `f(A, Q)` entry hit this because `lr_call` passes `f of (args)` with one list argument.
- The builder's description ("at a call-depth overflow") is imprecise: overflow is not required.

## OUT OF SCOPE (not judged)
- Values past 2^53, whole floats, inf/nan, NUL bytes (declared gaps I64/FLT/INF/NUL), and traceback names from the calling code (declared out of scope in R4).
- UNSUPPORTED exits I hit: io.open/io.lines with a file name, os.time with a table, os.date, debug.getlocal, string.dump, binary chunks.
- Table and function addresses (unspecified).
- Upstream filing of EigenScript issues (outside this session's repo scope).

## Scratch probes
/tmp/p/*.lua (n1-3, l1-4, c1-2, tr, tr2, ex1-7, mv2, tg, tg2, pp-pp4, gi, gi2, cs, hx, hx2, hx3, lm, pb), /tmp/shim (direct-translation control), /tmp/df (double-free reductions m1-m10, repro.eigs), /tmp/perf (subagent's callgrind variants). Nothing in the EigenLua source was edited or committed.
