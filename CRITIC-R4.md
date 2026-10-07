# CRITIC R4 — EigenLua frontend/r2 @ 6a491c7 (PR #6)

Runtime EigenScript 686d3b7d, reference PUC-Rio 5.4.9 from tools/build_ref.sh. Every PASS below is an oracle I ran.

## VERDICT: FAIL
The round's own items hold up (8/8 D rows flip DIVERGE→MATCH; the sort port is faithful line by line; C-stack depths and
tracebacks match at every depth probed; grader untouched; S=2/23 D=71/83 reproduced). It fails on ledger honesty:
LEDGER says "front-end bug (open): 0", but probing the brief's own surfaces finds seven in-scope front-end bugs (F1, F2, F4×3,
F5, F6) plus a minor one (F7), and three of them (F4) sit in math.lua right after the 25-failure stop the ledger calls "not reached".
Most are older than this round; none is filed.

Largest gap: F2 — `load` with a reader function lets reader errors escape instead of returning nil, msg.

## 1. D rows (8 new)
Ran `tools/grade.sh --only <8>` with candidate at 5f2722f (worktree) and at 6a491c7.
5f2722f: DIVERGE 8/8. 6a491c7: MATCH 8/8. PASS (oracle run).
## 8. Grader
`git diff origin/main..frontend/r2 --stat -- tools tests corpus`: only corpus/D/*.lua, corpus/D.manifest, tests/parse_all.sh (75->83). tools/ unchanged. PASS.

Full grade re-run (`tools/grade.sh --candidate bin/eigenlua --tier all`): `SUMMARY S=2/23 D=71/83 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=106` — matches the claim.

## 2. table.sort port
Line-by-line vs ltablib.c 5.4.9 (`sort`, `auxsort`, `partition`, `choosePivot`, `set2`, `sort_comp`): geti/seti order,
set2 top-first, both `invalid order function` checks (i == up-1, j < i), the unsigned wrap `(up-lo)/128 > n` (handled as
`up < lo or ...`), RANLIMIT 100, `rnd == 0` first pass, `n < INT_MAX`, checktype only when n > 1: **faithful**. Only
`l_randomizePivot` differs (wall clock since start vs clock()+time()) — unobservable beyond the reference's own randomness.

20 programs (scratch s01–s20): sizes 2..9, 50, 98, 99 with exact comparator traces and call counts, `__index`/`__newindex`/`__len`
proxies with read/write logs (n=2..9), duplicates, inconsistent comparators (always-true, `<=`), comparators that error
(string, table, nil), yield inside comparator (wrap & resume), `__lt` objects, comparator mutating the table, erroring proxies,
non-function comparators (number, false, callable table), builtin comparators, 100..5000 (result only), uncaught errors.
- MATCH: s02 s03 s04 s06 s10 s11 s12 s17 s18 s19 s20, s01/s08 (after removing >2^53 LCG arithmetic = I64 gap), s13 (after removing 0/0 = no-nonfinite gap).
- s05: only `%p` of a table address (unspecified). s07: inf / 1.0 / -0.0 / NUL printing (known FLT/INF/NUL gaps).
- s09: `__len` returning maxinteger -> "object length is not an integer" (I64 gap); `{1,nil,3}` border 1 vs 3 (unspecified class per GAPS.md:155 — not a finding).
- **s15 / c1 (front-end bug, F1):** a comparison error raised inside sort is located at the Lua caller:
  `local function f() table.sort({3,"x"}) end print(pcall(f))` ref `false	attempt to compare string with number`,
  cand `false	c1.lua:3: attempt to compare string with number`. Not sort-specific; see F1.

## FINDINGS (front-end bugs, in scope)

### F2 (largest) — `load` with a reader function does not protect the reader; errors escape `load`
Layer: runtime library, `src/runtime.eigs` `lr_b_load` (~line 2041: `lr_call1 of [chunk, [], 0]` unprotected).
lbaselib.c `luaB_load` -> `lua_load` -> `luaD_protectedparser`: any error raised by the reader (or by the C stack check when
calling it) is caught and `load` returns `nil, msg`. Pre-existing at 5f2722f (not a regression), but squarely in the brief's
"load with a reader function" surface and not covered by any D row.
```
print(pcall(load, function() error("x") end))
local ok, f, e = pcall(load, function() error({}) end) print(ok, f, type(e))
local ok, f, e = pcall(load, function() local x = nil .. "a" end) print(ok, f, e)
```
ref: `true	nil	k5.lua:1: x` / `true	nil	table` / `true	nil	k5.lua:5: attempt to concatenate a nil value`
cand: `false	k5.lua:1: x` / `false	table: 0x00000016	nil` / `false	k5.lua:5: attempt to concatenate a nil value	nil`
Uncaught (`print(load(function() error("x") end))`): ref prints `nil	k2.lua:1: x` + lua.c traceback text **on stdout**
(protectedparser keeps lua.c's msghandler as errfunc) and continues; cand dies rc=1.
Also surfaces in the C-stack probe: a `load`-reader recursion ends ref `true function: 0x…` (each inner load returns nil,"C stack overflow"),
cand `false C stack overflow`.

### F2b — the reader is drained eagerly instead of being pulled by the lexer
`lr_b_load` concatenates all pieces before compiling. Lua pulls pieces on demand, so a syntax error stops the reads:
```
local n = 0 local parts = {"x = ", "= 1", " y = 2", " z = 3"}
print(load(function() n = n + 1 return parts[n] end)) print(n)
```
ref `2`, cand `5` (message line matches). Observable side-effect order; same function.

### F1 — runtime errors raised inside a C library function get the Lua caller's position
Layer: `src/runtime.eigs:73-76` `lr_rterr`: for a site with no line (site 0 = called from C) it prepends `lr_where(1)`.
ldebug.c `luaG_runerror` adds a position only when the *current* ci is Lua (`isLua(ci)`); when the raise happens while a C
function runs (lua_compare/lua_geti/luaH_next inside table.sort, table.unpack, ipairs' iterator, next, math.max), there is none.
Pre-existing (ede05d7); violates rule 4's converse (a position Lua does not print).
```
print(pcall(function() table.sort({3,"x"}) end))
print(pcall(function() return table.unpack(5, 1, 2) end))
print(pcall(function() for i, v in ipairs(5) do end end))
print(pcall(function() return next({}, "nokey") end))
print(pcall(function() return math.max(1, {}) end))
```
ref: `false	attempt to compare string with number` / `false	attempt to index a number value` / `false	attempt to index a number value` /
`false	invalid key to 'next'` / `false	attempt to compare number with table`
cand: same messages prefixed `c2.lua:2: ` / `c2.lua:3: ` / `c2.lua:6: ` / `c2.lua:10: ` / `c2.lua:14: `.
(`pcall(table.sort, {1,"x",3})` directly matches only because level 1 is then pcall, a C function.)

### F4 — peel past 25 on math.lua finds three in-scope front-end bugs the ledger never reached
The ledger stops math at 25 failures (line 216). Continuing (my scripted peel, same method: blank the failing line, or the
calling line for a helper called ≥2 times) to line ~910:
- **math.lua:408 / 409-ish — `tonumber(s, base)` rejects a leading `+`** (lbaselib.c `luaL_str2int`: `else if (*s == '+') s++;`).
  `print(tonumber('  +1Z  ', 36), tonumber('+10', 2))` ref `71	2`, cand `nil	nil`. Layer: runtime `tonumber` with base.
- **math.lua:427, 434 — long hex numerals parse to 0** (lobject.c `lua_strx2number` keeps MAXSIGDIG=30 significant digits and
  counts the rest into the exponent). `print(tonumber('0x3.' .. string.rep('0', 1000)), tonumber('0xe03' .. string.rep('0', 1000) .. 'p-4000'))`
  ref `3.0	3587.0`, cand `0	0` (with 40 zeros cand gives 3, so the cut is somewhere past 40 digits). A wrong value, not the FLT gap.
- **math.lua:293 — "has no integer representation" lacks varinfo** (ldebug.c `luaG_tointerror` -> `varinfo`).
  `print(pcall(load("local a = 2.5 return a << 1")))` ref `…:1: number (local 'a') has no integer representation`,
  cand `…:1: number has no integer representation`; same for `(field 'huge')`, `(field 'x')`. varinfo is already implemented for
  index/call/arith errors, so this is a missing direct translation.
Everything else past 25 in math is I64 / INF / FLT (614-656, 705-741, 773-796, 909) or SYN from blanking; peel stopped at a
goto/label SYN cascade at 924.

### F5 — `debug.traceback(thread, ...)` walks the caller's stack, not the thread's
Layer: `src/runtime.eigs:2386` `lr_d_traceback`: the thread argument shifts the arg index but `lr_tb_last`/`lr_d_frame`
always read the running stack; ldblib.c also defaults the level to 0 for another thread (cand uses 1 always).
```
local co = coroutine.create(function() local function g() coroutine.yield() end g() end)
coroutine.resume(co) print(debug.traceback(co, "msg co"))
print(debug.traceback(coroutine.create(print), "fresh"))
```
ref: `msg co` / `stack traceback:` / `[C]: in function 'coroutine.yield'` / `tbx.lua:14: in local 'g'` / `tbx.lua:14: in function <tbx.lua:14>`;
`fresh` / `stack traceback:` (nothing else).
cand: `msg co` / `stack traceback:` / `tbx.lua:17: in main chunk` / `[C]: in ?` — the *main* stack; `fresh` also gets main-chunk lines.
(traceback is in scope per GAPS.md; only names-from-code are OOS. `debug.getinfo` of another coroutine is honestly UNSUPPORTED; traceback silently lies.)

### F6 — `os.exit(code, true)` does not close the state
lua.c/loslib.c `os_exit`: `if (lua_toboolean(L, 2)) lua_close(L);` closes pending to-be-closed variables.
`local x <close> = setmetatable({}, {__close=function() print("closed") end}) os.exit(0, true)` ref prints `closed`, cand prints nothing.
Same function the round claims fixed (item 3). Layer: runtime `os.exit`.

### F7 — `load` mode check ignores the binary signature (minor)
`print(load("\27Lua", "b", "t"))` ref `nil	attempt to load a binary chunk (mode is 't')`, cand `nil	[string "b"]:1: unexpected symbol near '<\27>'`.
(ldo.c `checkmode` on the first byte.) The default-mode case (`bad binary format`) is undump territory, arguably OOS with string.dump.

### Shims (item 6)
- `%p` of a string (`src/rt_format.eigs:647-659`): besides the fresh-per-call long-string number already filed (#12), the
  **short-string branch is a djb2 hash mod 2^31-1, which collides across distinct strings**:
  `print(string.format("%p", "Ab") == string.format("%p", "BA"))` ref `false`, cand `true` (33·'A'+'b' = 33·'B'+'A').
  Hash values (e.g. `%p` of `""` = 0x1505) also share the number space with table/function ids, so a string and a table can
  print the same `%p`. Same root cause as #12, but a distinct observable wrong answer that #12's text ("fresh number per call")
  does not cover.
- No other substitute found: grep for substitute/approximate/emulate/placeholder, read collectgarbage (OOS counts),
  sort's l_randomizePivot (unobservable), for-loop precount (lvm.c forprep, direct).
- `lr_fstk`: tracebacks after 5× pcall unwinds from depth 30, after `__close` erroring during unwind, after a wrap'd
  coroutine errors after yield, after `coroutine.close`, inside xpcall handlers, and `getinfo(2).currentline` after unwinds — all
  match the reference modulo OOS names (f1.lua). No leak observed.
- UNSUPPORTED sites: `to-be-closed variable in a block with labels` (emit.eigs:645) is an unimplemented front-end feature —
  legit exit 3 per rule 2, but note it is reachable from ordinary code (`do local x <close> = … goto skip … ::skip:: end`).

## 3. C-stack probes
k1/k7 (scratch): recursion depth and message vs reference through `__eq __lt __le __concat __len __unm __idiv __band`,
`__index` fn and 300-deep `__index` chain, `tostring`/`print`/`string.format("%s")` with `__tostring`, `gsub` with a function and
with a `__index` table, sort comparator, pcall, xpcall, `coroutine.wrap` and `resume` chains, ipairs over `__index`, generic-for,
`table.concat`/`insert`/`unpack` through metamethods, `__len` + rawlen, string metatable `__index`, `__close` recursion.
**All depths and messages match** (e.g. 196 levels, `C stack overflow`), except:
- `load` reader recursion: ref `true function…`, cand `false C stack overflow` → F2 (load doesn't protect the reader), not the counter.
- Lua-only recursion (`select(1, f())`, `load("return ...")(f())`): ref `stack overflow` at ~333k/~500k, cand VM call-depth at ~2040 → known call-depth gap.
Yield-inside-counted-call boundaries: probe depth after yields inside `__index`, inside pcall, inside `__add`; 300 yields from
inside counted calls (metamethod, pcall, generic-for iterator) then probe — **no drift, all match**. Nested wrap/resume chains of
1/5/20/50 levels: match. Yield across sort comparator / gsub / tostring / load reader: messages match except load (F2).

## 4. Traceback probes
Recursion at depths 5, 10, 11, 21, 22, 100 (local recursive + global recursive): after normalizing the OOS name text
(`upvalue 'rec'`/`local 'rec'` vs `function <…>`) **all match line-for-line**, including the `...	(skipping N levels)` line.
Level 0/1/2/3, -1, 50, message table/nil/number/bool, `traceback() ` no args, in a coroutine (level 1 inside nested g),
inside wrap, pcall(debug.traceback), xpcall handler, from `__index`: match modulo names. **Fails only with a thread argument (F5).**

## 5. Peel re-check
| row | my result | builder |
|---|---|---|
| sort | 30 failures, END; ref 258463 = cand 258463, stdout same. Failures 26-30: 182-187 I64, 199 I64 (`__len` = maxI). **Line 184 `table.move({}, minI, -1, 1)` HANGS** (likely: maxI+minI = 0 in doubles, so the wrap check passes and n = 2^63; with 184 blanked the row runs to END) — the 26th failure, an I64 hang the ledger never saw. | stopped at 25, "not reached" |
| math | to line ~910: 40+ more failures; **3 front-end bugs hidden past 25 (F4)**; rest I64/INF/FLT/SYN | stopped at 25 |
| tpack | 60 failures to line 256, all NUL/I64/INF or SYN from blanking — matches the builder's classes | stopped at 25 |
| bitwise | 14 failures identical to ledger, END, 1314 = 1314, stdout same | same |
| literals | 9 failures identical to ledger, END, 614 = 614, stdout same | same |
| utf8 | charpattern replaced, 218/236/247-256 blanked: 847 = 847, stdout same | same |
The ledger's first-25 classifications I re-derived on sort/math/tpack all agree; the problem is what sits after 25.

## 7. Fresh programs (n01–n22, scratch)
MATCH: integer `//`/`%` incl. negatives and errors (modulo FLT print), string.rep with separator, select negative indexes and
errors, table.concat with numbers/errors, byte/char round trip of all 255 non-NUL bytes and errors, utf8.codes/len/offset/codepoint
errors (lax and strict), coroutine.close in all states incl. erroring `__close`, table error objects through pcall/xpcall chains,
load with reader+env (when the reader doesn't error), goto into nested function / into block / duplicate label / jump into local
scope (all rejected identically), float-step for loops, `<close>`/`<const>` errors, metamethod truthiness, gsub/find/match edge
cases, table.insert/remove/unpack/move, varargs.
DIFF and classified: FLT (`1.0`, `3.0`, `1e+15`), INF, NUL (`%q` of `\0`), addresses (unspecified), `getinfo` option check (OOS),
and the bugs F6, F7 above.

## OUT OF SCOPE (not counted against the round)
Traceback/getinfo names from code (`upvalue 'rec'`, `local 'f'`, `metamethod 'index'`); `debug.getinfo` option validation;
table/function/thread addresses; `#t` border with holes (unspecified, GAPS.md:155); `bad binary format` for undump
(string.dump); `collectgarbage` counts; all I64 / FLT / INF / NUL / call-depth / task-limit divergences, which are filed gaps.
