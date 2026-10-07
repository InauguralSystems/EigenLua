# CRITIC R6 report (blind critic, head a0b64ef)

## 1. D rows (run by critic)
Head grader, `--only` the 9 new rows. Candidate /tmp/r5/bin/eigenlua (79e29669): `D=0/9 diverge=9`. Candidate head: `D=9/9`. PASS.
Caveat: load_chunk_sites.lua (#29) diverges at base only on `what`='Lua' vs 'main' (line 7), not on the #29 memory change, which is not visible on stdout (the builder says so).

## 2. Claimed fixes, probed beyond the D rows
### #24 reader counts — PASS
3 own programs (critic scratch p24a/b/c): 30 + 25 + 20 sources (syntax errors, const/close attribute errors, goto/label/break errors, too-many-locals, errors in nested functions, method-call chains, long strings/comments spanning chunk boundaries, escapes, numerals) x readers of 1/2/3/5/7(/11) chars, printing read count + message. All SAME as reference (stdout+rc). Base 79e29669 differs on 7/5/many lines of the same programs.

### #25 hex subnormals — PASS
p25a: 5000 hex numerals from Park-Miller MINSTD (48271, seed 20261007; builder used an LCG seed 12345), 1-30 hex digits, optional point, 5 exponent classes; each via tonumber AND load, printed `%a` + `%.17g`. Ref classes: 1325 zero (underflow), 571 inf, 1150 subnormal, 1954 normal. Head: the only differing lines (603) are values whose reference result is inf or > 1e308 — EigenScript saturates every value above 1e308 to 1e308 even as a literal (`print of (1.7e308 + 0.0)` -> 1e+308): `no-nonfinite` gap. 0 other differences (base: 23 other). p25b: 39 edge numerals (ties-to-even at 2^-1075, 0x0.fffffffffffff8p-1022 carry into normal, sticky bits after 300 digits, 400 leading zeros, exponent -2^31 / -99999999999, malformed) — only the DBL_MAX row differs (saturation). p25c: 1000 numerals via string coercion (`str+0`, padded `*1`, unary minus of "-..."): SAME (base differs).
Note (not a claim failure): GAPS/LEDGER describe no-nonfinite as "overflow saturates at 1e308"; in fact every finite value in (1e308, DBL_MAX] is clamped too, including exact literals.

### #26 handler before close — PASS on the claim
p26a (4-frame nested `__close`, error in handler, error in two `__close`s each re-routed, error in `__close` on normal exit, xpcall nested in a `__close`, traceback in handler), p26b (xpcall in coroutine across yield, wrap error into xpcall, coroutine.close with erroring `__close` under xpcall, yielding `__close`, handler traceback in coroutine), p26c (handler returning 0/3 values, nested xpcall handlers, runtime arith/index/call errors, level-2 errors, extra args, callable-table handler, `__tostring` objects, library arg errors), p26d-f (lua.c handler + main-chunk `__close`). Everything the claim covers matches; base differs on p26b/p26c. Remaining diffs are outside the claim (listed under new bugs: handler recursion limit, eager coroutine tbc close) or OOS (traceback function names "in local 'f'").

### #27 one id space — PASS
p27a: 10000 live objects (tables, closures, threads, tables with metatables): 0 duplicate `%p`, tostring address == `%p` for each; free half, collect, 10000 new: 0 clash with a live id (base: mismatch at object 4, 3737 clashes). p27b: 13k mixed objects incl. 3000 distinct short strings, all string/table/math C functions, io.stdout/err/in, _G: 0 distinct-object clashes; equal short strings share an id. p27c: 20 rounds of churn with random survivors + collectgarbage: 0 clashes. All SAME.

### #28 argument errors — PASS on the 5 issue items (1-3, 5 fixed; 4 is a GAP)
p28a: 12 math.random arg shapes, 12 getinfo option strings, getinfo with bad level/types/functions, get/setupvalue/upvalueid in every arg-order combination: SAME (upvaluejoin removed: UNSUPPORTED, declared OOS in the inventory). p28b: 13 binary events + bnot/unm/len/lt/le/call/index/newindex/method with C metamethods, C functions called by name/local/field/method, C metamethods reached via tostring/unpack/insert/ipairs: all match except `t:f()` with f=string.rep (see new bugs: "bad self" message lacks its extramsg — pre-existing, not one of #28's five items).
GAP no-errno: confirmed. v0.45.0 exposes only read_text/read_bytes/file_exists for files; read_bytes of a missing file and of a directory both return null, read_text gives "" for missing/empty, no errno anywhere in the builtins. Reproducer runs; its middle line needs the `touch /tmp/f && chmod 000` setup its header states (on a fresh box it prints `["", false]` for /tmp/f, not the `["", true]` the header claims as Actual).

### #22 genfor close line — PASS
p22a (nested loops with inner break, return from inner loop across lines, goto out of 2 loops, continue-goto, pcall/xpcall error, one-line loop, 5-line header, erroring iterator, tail-position return, `next` with close value), p22b (body `<close>` + loop close order, nil/false closing value, non-closable 42/{} errors, repeat-break inside, backward goto, erroring loop `__close`, error object passed), p22c (loops inside a load()ed chunk, method iterator): every claimed line matches (base differs). Two diffs outside the claim, both pre-existing (new bugs below): a loop closed by coroutine.close sees getinfo(2) = -1 not nil; `for k in pairs(t), nil` runs instead of erroring.

### #29 sites — PASS (claim confirmed)
p29a: 12000 loads of a 6-line chunk with locals, table constructor, closure, loop, concat; os.clock per load.
| | peak RSS | worst load | mean | wall |
|---|---|---|---|---|
| 79e29669 | 733,836 KB | 3847.7 ms | 5.60 ms | 70.7 s |
| head a0b64ef | 20,316 KB | 33.5 ms | 4.75 ms | 57.4 s |
| PUC 5.4.9 | 2,556 KB | 0.3 ms | 0.013 ms | 0.17 s |
Builder's 20 MB head figure reproduced exactly; base is worse here than the builder's 199 MB/713 ms (different chunk). p29b: early chunk kept alive across 6000 throwaway loads + full GCs, 50 child chunks whose parent chunk was collected, 200 `@file` chunks: error messages, source/short_src/linedefined/lastlinedefined/what/currentline all SAME; only diff is traceback function names (OOS).

## 3. Full grade (critic run, head)
`SUMMARY S=2/23 D=96/108 fail=15 diverge=12 hang=2 crash=0 unsupported=4 examined=131 assert=trusted` — identical to the claim.

## 4. #21 gates
- `git diff 79e29669..frontend/r6 -- tools tests` (the round's own change; see note) touches only: grade.sh header comment + guard:dup-manifest + the operators:-twice check + guard:builtins; selftest.sh's 3 new plants and plant list; parse_all.sh's 99->108 count and 0.44.0->0.45.0 version check. PASS.
- Note: `origin/main..frontend/r6` two-dot also shows main's #30 bump (Dockerfile/README/bin/eigenlua) in reverse; frontend/r6 does not contain d8f3f0f and conflicts with it textually on bin/eigenlua and README (Dockerfile would revert to v0.44.0 if taken as-is). Merge hazard, not a claim failure.
- Critic plants (staged copies, `--candidate` = reference): dup real row -> red "duplicate D manifest line"; dup with trailing space -> red (row-level check); dup operators: line -> red; second different operators: line -> red; math.floor cited to a row not naming it -> red; name only in a full-line comment -> red; bogus extra name -> red; dropped name (utf8.char) -> red; `uncovered:` without reason -> red; nonexistent row -> red; duplicate inventory line -> red; control -> green.
- Holes (textual check, builder's caveat admits it): name only in a TRAILING comment (`print(1) -- string.rep`) is accepted as a citation (green); for a library field, any `"floor"` string literal anywhere cites math.floor (green).
- Inventory vs reference: my own pairs walk of `.ref/bin/lua` (_G non-tables + every table global's fields) equals the inventory's 142 names exactly (except `arg`'s numeric fields, an artifact of my walk). The report/LEDGER say "150 names, 128 covered, 22 uncovered"; the real counts are 142 names, 121 cited, 21 uncovered (150 is the file's line count incl. 8 comment lines). Doc inaccuracy only.

## 5. #1661 safety — PASS (no trigger found)
- Confirmed the bug exists on v0.45.0: EigenScript's own repro (tests/test_underarity_1661_repro.eigs from fix c17dff1c, not in v0.45.0) gives `heap-use-after-free ... slot_as_double` under an ASan build of v0.45.0 and `malloc_consolidate(): unaligned fastbin chunk` on release.
- Static: a perl scan of every `name of [..]` call against every `define name(p1, p2, ..)` (232 functions with 2+ params) in src/*.eigs AND in the emitted programs of 172 compiled sources (all D rows, all S files, my probes): 0 under-arity calls (1 false hit inside an emit string literal, which emits 3 args to lr_tbc_check(3)). No 2+-param function is ever referenced as a value (dict/list member, assignment, argument), so none is reachable through a dynamic `f of (args)`; emitted Lua functions are `F(U)`/`f(A)` (1 param) and `L(ENV, SRC)` is always called with 2.
- Dynamic: a Lua program recursing 1200 Lua levels (~3600+ VM frames) through `__index`/`__add`/`__call` metamethods, `<close>`, pairs, pcall(error), under-arity Lua calls, a 1200-deep r2 with `select('#')`, a coroutine, gsub callbacks x2000, table.sort with comparator: ASan build, default tier and EIGS_JIT_ENTRY_THRESHOLD=1: 0 ASan/UBSan reports, output as release. The 8 fast new D rows under ASan + forced JIT: all MATCH, 0 reports.

## 6. Shims (this round's `+` lines)
Read the whole `git diff 79e29669..frontend/r6 -- src`. Hex-float rounding (lex.eigs/runtime.eigs lr_hexd) is a direct bit-exact round-half-even at the result's precision — not a substitute. One id space = a shared counter (pre-existing approach to addresses; values are unspecified in Lua). lr_errhd runs the xpcall handler at the first pending `__close` (or xpcall's catch when none): p26g checked the handler's getinfo stack 8 levels deep, with and without an outer `<close>`, for error() and runtime errors — SAME, so the stack is not lost. setlocale's category check, getinfo's option check, checkfn: direct ports of loslib/ldblib. **No shim found in this round's lines.** (Pre-existing shim outside the round: `pairs` — see new bugs.)

## 7. Claim failure: the probe-found fix b9b1a6b (err_index_varinfo.lua) is incomplete
The round lists "probe | FIXED | ... now getobjname's rules". The emitter classifies the key by AST kind (Str / non-float Num 0..255), but Lua's getobjname sees bytecode after constant folding, so a folded key is OP_GETFIELD / OP_GETI:
```lua
local t = {}
local K <const> = "kk"
local N <const> = 5
pcall(function() return t[K].x end)   -- ref (field 'kk')            cand (field '?')
pcall(function() return t[N].x end)   -- ref (field 'integer index') cand (field '?')
pcall(function() return t[1+1].x end) -- ref (field 'integer index') cand (field '?')
pcall(function() return t[-(-1)].x end), t[3//1].x, and the assignment t[1+1].x = 1: same
```
At 79e29669 all of these said (field 'x') (also wrong). 25 other index/call/arith shapes (critic idx.lua) match. Severity low, but by the merge rule an incomplete claimed fix fails the round on this point.

## 8. New bugs found by probing BEYOND the claims (do not fail the round; all pre-existing at 79e29669)
1. **`calling 'f' on bad self` drops its reason.** `local t={f=string.rep}; t:f()` -> ref `calling 'f' on bad self (string expected, got table)`, cand without the parenthesis (runtime.eigs lr_argerr: line 120 never appends msg). Same for `s:sub()`.
2. **An erroring coroutine closes its `<close>` variables at the error.** `coroutine.create(function() local w <close> = ... error("e",0) end)`: ref closes `w` only at `coroutine.close(c)` (lua_resume leaves the stack); cand closes it inside the failing resume. (coroutine.wrap is correct: it closes on error.)
3. **Error in an xpcall handler: wrong recursion.** `xpcall(error, function(m) error("in handler") end, "x")`: ref calls the handler 215 times and passes it "C stack overflow" at call 197; cand calls it 200 times and never passes "C stack overflow" (then both give "error in error handling").
4. **`pairs` is a substitute iterator (rule 1).** lr_b_pairs snapshots the keys into a closure instead of returning `next, t, nil`: `(pairs(t)) == next` is false (ref true), and `for k in pairs(t), nil do` iterates (ref: "bad argument #1 to 'for iterator' (table expected, got nil)").
5. **getinfo inside a `__close` run by `coroutine.close`:** level 2 is the resumer's frame (`-1`, then a table) instead of nil (genfor or plain `<close>`).
6. Gate holes (#21, textual check): a builtin named only in a trailing comment (`print(1) -- string.rep`) or, for a library field, as any `"floor"` string literal counts as a citation.

## 9. Doc inaccuracies (not claim failures)
- R6-REPORT/LEDGER: "150 names, 128 covered, 22 uncovered" — the inventory has 142 names (150 lines incl. 8 comments), 121 cited, 21 uncovered.
- no-nonfinite says "overflow saturates at 1e308"; EigenScript clamps every finite value in (1e308, DBL_MAX] too, even a literal (`print of (1.7e308 + 0.0)` -> 1e+308); 603/5000 of my hex-float lines differ only by this.
- gaps/no-errno.eigs's "Actual" line `["", true]` for /tmp/f holds only after the header's `touch /tmp/f && chmod 000` step; a fresh run prints `["", false]`. The gap itself is real.
- Merge hazard: frontend/r6 does not contain main's d8f3f0f (#30 bump); bin/eigenlua and README conflict, and taking r6's Dockerfile would revert EIGS_REF to v0.44.0.

## 10. Out of scope (not judged)
Traceback function names (`in local 'f'`, `in upvalue 'a'`), debug.upvaluejoin (UNSUPPORTED, inventory-declared), int64 (no-int64: also makes hex integer literals > 2^63 floats), call depth (call-depth), string.dump, binary chunks, getinfo of other coroutines. Tooling note: `make asan` in /tmp/es overwrote src/eigenscript with the ASan binary (hard link); all release-runtime measurements were taken before it or with build/release/eigenscript.

## VERDICT
The 8 numbered issues' claims hold: #21 (gates go red on 11 plants, inventory equals the reference's names, diff limited to the gates + parse_all count/version, 31/31 selftest plants OK), #22, #24, #25, #26, #27, #28 (+ a real errno GAP), #29 (734 MB/3.85 s -> 20 MB/33.5 ms worst on 12k loads). All 9 D rows diverge at 79e29669 and match at head; full grade reproduces the claimed SUMMARY; no #1661 trigger; no shim in this round's lines. **One claim fails: the listed probe-found fix (getobjname naming, b9b1a6b) misses constant-folded keys** (`t[K]` with `<const>` K, `t[1+1]`). Strictly by the merge rule: FAIL on that one row; everything else PASS.
