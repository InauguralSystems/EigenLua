# EigenLua round 5: builder report

Branch `frontend/r5`, from round 4's merge 8a30e385 (PR #6). Runtime: EigenScript 686d3b7d. Reference: PUC-Rio
Lua 5.4.9 from `tools/build_ref.sh`. The grader, the plants and the existing corpus files are unchanged; round 5
added 16 Tier D programs, their manifest lines and the D count in `tests/parse_all.sh`.

## SUMMARY

- **Before** (8a30e385, re-measured at the start of this round):
  `SUMMARY S=2/23 D=71/83 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=106 assert=trusted`
- **After** (`tools/grade.sh --candidate bin/eigenlua --tier all`):
  `SUMMARY S=2/23 D=87/99 fail=16 diverge=12 hang=1 crash=0 unsupported=4 examined=122 assert=trusted`

All 16 new D rows MATCH. At 8a30e385 (`--candidate <8a30e385 checkout> --only <the 16>`):
`SUMMARY S=0/0 D=3/16 fail=0 diverge=10 hang=1 crash=0 unsupported=2 examined=16` - every issue row fails there
(tbl_move_overflow HANGs, tbc_goto_labels and debug_getinfo_source_close are UNSUPPORTED); the 3 that match there
are coverage (tbl_library, builtin_values) and a regression guard (lex_near_raw). The 12 DIVERGE rows and every S
row's first failure are unchanged: all EigenScript gaps or out of scope.

## Per issue

| issue | result | evidence |
|---|---|---|
| #13 load reader | FIXED | load_reader_protected.lua. `print(pcall(load, function() error("x") end))` gives `true nil k5.lua:1: x`. The lexer makes tokens as the parser asks and reads a piece only when an item reaches the end of its text; all 13 read-count probes match (the issue's syntax error stops after 2 reads). Reader errors also pass through the message handler in force (lua.c's traceback at top level), as L->errfunc does. |
| #14 C positions | FIXED | err_c_function_unlocated.lua: next, sort's compare, the ipairs iterator, math.max/min. table.unpack's errors come from `__index` (Lua, located) or luaL_error (located) and already matched. |
| #15 numbers | FIXED | num_str2num_edges.lua. `tonumber('+10', 2)` = 2; `tonumber('0x3.'..('0'):rep(1000)) == 3`; `number (local 'a') has no integer representation`. Hex floats are strtod's correctly rounded value: 5.4.9's luaconf.h defines lua_strx2number as strtod under C99, so the MAXSIGDIG code is not compiled (same 3.0). |
| #16 traceback(thread) | FIXED | debug_traceback_thread.lua (suspended, dead by error, finished, fresh, self, from another coroutine). |
| #17 os.exit close | FIXED | os_exit_close.lua: closes innermost first, an error in one passed to the next, a coroutine's not closed. |
| #18 load mode | FIXED | load_mode_binary.lua: `nil attempt to load a binary chunk (mode is 't')`. |
| #19 table.move | FIXED | tbl_move_overflow.lua (HANG at 8a30e385). The checks compare against the C constant LUA_MAXINTEGER, so they are computed exactly on 32-bit limbs. Arguments past 2^53 (maxI, minI + 1) still round: `no-int64`. |
| #20 `<close>` + labels | FIXED | tbc_goto_labels.lua: goto to the end label, backward goto, goto out of a loop, break, return, error, repeat-until. |
| #12 `%p` of a string | FIXED (direct translation) | str_format_p_string.lua. Choice: the same id scheme as tables, keyed by the string value (identity-stable: a string is its value in EigenScript). One string always formats alike (pm.lua 413/416/426, literals 225-228 now hold); an equal long string built by concatenation diverges (literals.lua:230), `gaps/no-string-identity.eigs` updated. |
| #8 getinfo | FIXED | debug_getinfo_source_close.lua: `source` is the chunk text, `=name` or `@file`; `__close` sees lparser.c's closing line (block's last token, function `end`, return, loop end for break, forward goto's label, backward goto's line). |
| #11 approximations | FIXED + GAP | meta_cstack_kinds.lua (C-stack depth per boundary kind, all match), cstack_yield_resume.lua (pcall restore after a resume inside it), print_partial.lua (found by the probe). Boundary table and VM-error locations in LEDGER.md. xpcall after overflow: `gaps/handler-after-overflow.eigs` prints `[true, 0, true, 4094]`. |
| #9 upvalue query | FIXED | See below: 1.38% per call. |
| #7 load speed | GAP | `gaps/vm-op-cost.eigs`; closure.lua's HANG is `no-weak-refs`, not speed. See below. |
| #10 pipe reads | GAP | `gaps/pipe-read-line.eigs`: `printf 'a\r\nb'` and `printf 'a\r\nb\n'` both print `["a", 1, "b", 1, null]`. No upstream issue filed (EigenScript is outside this session's repository scope). |
| #2, #3 coverage | MATCH | tbl_library.lua, builtin_values.lua (seedA = seedB). Planted `table.insert` ignoring its position diverges at tbl_library line 7; planted `math.type(1) == "float"` at builtin_values line 88. The grader gates #3 also asks for are grader changes, out of scope here. |

## #9 measurement

Loop: `local function f(x) return x + 1 end; for i = 1, N do s = f(s) end`.
- valgrind instruction counts, N = 100000, startup subtracted: query test `if A == null` 2942.65M; test deleted
  2902.57M (**+1.38%**); 8a30e385 (`if type of A == "dict"`) 3086.07M.
- paired CPU time, N = 1000000, 5 runs: new/8a30e385 = 0.807, 0.886, 0.971, 0.976, 0.948; **median 0.9475**. This
  VM's timings vary by about 15%, so the instruction count is the reliable number.
- A two-parameter entry `f(A, Q)` was tried and dropped: the VM aborted with "double free or corruption" at a
  call-depth overflow (no minimal reproducer was isolated).

## #7 measurement

In the runtime on 686d3b7d: `load("return 1")` about 0.24 ms (lex 25 us, parse 41, emit 46, eval 32, the rest site
bookkeeping and a larger heap); a constructs.lua chunk (about 230 characters) about 1.2 ms (lex 0.39, parse 0.39,
emit 0.39, eval 0.08 ms). The #13 lexer split had doubled lexing (0.34 -> 0.78 ms); one call lexes a whole chunk
again. `gaps/vm-op-cost.eigs` measures the VM alone: 0.25 us per character looked at, 0.18 us per call, 0.68 us per
dict literal, 17 us per eval of a 7-line chunk; a minimal front end then needs about 534 us per such chunk, 1.8x the
300 us per load the row's budget allows (20 x 2.3 s / 200000). The 0.1 ms target for a short chunk is not met.

## LEDGER counts

| class | rows | S | D |
|---|---|---|---|
| EigenScript gap | 27 | 15 | 12 |
| out of scope | 6 | 6 | 0 |
| front-end bug (open) | 0 | 0 | 0 |
| unspecified | 0 | 0 | 0 |
| PASS / MATCH | 89 | 2 | 87 |

The zero is for graded rows only; probe-found bugs are listed by issue in LEDGER.md.

## COMMITS

```
bec2e2a Tier D coverage: the table library and builtin return values (EigenLua#2, EigenLua#3)
d960433 C-stack count exact across resume; print writes as it converts; overflow-handler gap (EigenLua#11)
c385342 gaps/pipe-read-line.eigs: read_line on a pipe loses '\r' and the final newline (EigenLua#10)
b1f57e3 gaps/vm-op-cost.eigs: the VM's per-operation cost floors load's speed (EigenLua#7)
4af20f6 Lexer: one call lexes a whole chunk again; drop two stray lines in lex_item (EigenLua#7, EigenLua#13)
b98ce6e Upvalue query: test the argument list against null, 1.4% per call (EigenLua#9)
ff030a5 %p of a string names the string value, not a substitute (EigenLua#12)
51ef0f9 debug.getinfo: source of loaded chunks; __close sees its closing line (EigenLua#8)
53c2c94 To-be-closed variables in blocks with labels (EigenLua#20)
3c347f4 table.move: ltablib.c's overflow checks on exact limbs; no hang at minI (EigenLua#19)
b6d5152 debug.traceback(thread): walk the thread's own stack, default level 0 (EigenLua#16)
fe65e23 os.exit(code, true) closes the main thread's pending variables (EigenLua#17)
2fa452c load: reader errors return nil, msg; pieces read on demand; mode checks the signature (EigenLua#13, EigenLua#18)
5e6e580 tonumber base '+', strtod hex floats, tointerror varinfo (EigenLua#15)
be5385f Errors raised while a C function runs carry no position (EigenLua#14)
(plus the final commit: LEDGER, README, this report)
```

## Tests

`bash tests/parse_all.sh` (tail):
```
parsed=122/122
```
`bash tests/run.sh` (tail):
```
ROW D xpcall_handler_frame.lua MATCH rc=0
SUMMARY S=23/23 D=99/99 fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=122 assert=trusted
RUN ok

(all 28 PLANT lines in the self-test report OK)
```

## Caveats

- #13 and #18 share one commit (the mode check needs the first read).
- Commit 2fa452c had a lexer bug (an extra raw-text entry per item) that crashed on some syntax errors; 4af20f6
  fixed it and added lex_near_raw.lua. Nothing between them was graded.
- Out of scope this round: grader gates for #3 (declared builtin list, duplicate manifest lines), binary chunks,
  `getinfo` of another coroutine, an upstream issue for #10.
- The `__close` line rules (#8) were derived from the reference's behaviour on 13 shapes; the generic for's
  closing value still closes at the loop's declaration site.
