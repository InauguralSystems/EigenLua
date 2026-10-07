# EigenLua round 6: builder report

Branch `frontend/r6`, from round 5's merge 79e29669 (PR #23). Runtime: EigenScript v0.45.0 (symlinked on PATH).
Reference: PUC-Rio Lua 5.4.9 from `tools/build_ref.sh`. Round 6 added 9 Tier D programs, their manifest lines, the
D count in `tests/parse_all.sh` (which now checks for v0.45.0), `gaps/no-errno.eigs`, `corpus/builtins.inventory`,
and **one grader change**: the #21 gates in `tools/grade.sh`, with three plants in `tools/selftest.sh`.

## SUMMARY

- **Before** (79e29669 on v0.45.0, its own corpus):
  `SUMMARY S=2/23 D=87/99 fail=15 diverge=12 hang=2 crash=0 unsupported=4 examined=122 assert=trusted`
- **After** (`tools/grade.sh --candidate bin/eigenlua --tier all`):
  `SUMMARY S=2/23 D=96/108 fail=15 diverge=12 hang=2 crash=0 unsupported=4 examined=131 assert=trusted`

Round 5 measured fail=16 hang=1 on 686d3b7d. On v0.45.0 cstack.lua is a HANG at both commits: it runs about 20-23 s
against its 20 s budget (the reference takes 0.2 s) before its unchanged first failure, 105 TL (`task-limit`).

All 9 new D rows MATCH. At 79e29669 (`--candidate <79e29669 checkout> --only <the 9>`):
`SUMMARY S=0/0 D=0/9 fail=0 diverge=9 hang=0 crash=0 unsupported=0 examined=9`. The 12 DIVERGE rows are round 5's
12, all EigenScript gaps.

## Per issue

| issue | result | evidence |
|---|---|---|
| #24 reader counts | FIXED | load_reader_counts.lua. `x = {1,,3}` with a 1-char reader: 9 reads, as the reference. (a) a field looks ahead only past a name; (b) check_readonly is raised by the parser at the `=`/`,` (and after a function statement's body), with each local's attribute and lparser.c's scopes, a repeat body's included in its condition; (c) "unknown attribute" after `checknext('>')`. 8 sources x 1/2/3/7-char readers, plus 13 readonly shapes. |
| #25 hex subnormals | FIXED | num_hexfloat_subnormal.lua. `0x6802b8098be00bbp-1081` = 1.8080571335622205e-308. One rounding at the result's precision (53 bits or down to 2^-1074), in both the lexer and tonumber. 3000 numerals (LCG seed 12345, 14-23 digits, 2773 subnormal), printed exactly as multiples of 2^-1074; 30 differed at 79e29669. |
| #26 handler before close | FIXED | xpcall_handler_close.lua: `handler` before `close`; each `__close` gets the handler's result; an error in a `__close` goes through the handler again; with os.exit in a `__close` the handler has run. lua.c's handler too (the main chunk's `__close` sees the traceback). |
| #27 one id space | FIXED | ptr_id_space.lua: 31 duplicate `%p` addresses at 79e29669, 0 now. tostring's address is lower case, as `%p`. |
| #28 argument errors | FIXED + GAP | lib_argerr_names.lua: random #1; getinfo `'>'`/invalid option (an out-of-range level returns nil first; only the 'S'/'l' fields asked for); setupvalue #3 first; metamethod C functions named 'index', 'add', 'len', 'unm', ... The errno text: `gaps/no-errno.eigs` prints `["", false]` / `["", true]` / `["", true]` (missing, unreadable as root, empty: no reason). |
| #29 sites | FIXED (no stdout divergence) | Sites of a loaded chunk are its own list, freed with it. load_chunk_sites.lua guards positions and debug info in loaded code; it diverges at 79e29669 only on a probe-found `what` bug, since memory is not visible on stdout. Measurements below. |
| #21 grader gates | DONE (grader change) | `guard:dup-manifest` (plant dup-manifest) and `guard:builtins` (plants builtin-missing, builtin-uncited): 150 names, 128 covered, 22 uncovered with reasons. Coverage row builtin_values_more.lua (found `os.setlocale` ignoring a bad category, fixed). All 31 plants OK. |
| #22 genfor close line | FIXED | genfor_close_line.lua: loop `end` line on normal exit and break; label line on goto; return line; -1 on error. |
| probe | FIXED | err_index_varinfo.lua: `pcall(print).y` said `(field 'y')`; now getobjname's rules. |

## #29 measurements

| | 79e29669 | round 6 |
|---|---|---|
| 12000 loads of a constructs-shaped chunk: peak RSS / worst load | 199 MB / 713 ms | 20 MB / 17.5 ms (48000 loads: 20 MB) |
| constructs.lua (306 blanked), whole run: peak RSS / wall | 7.69 GB / 767 s | 2.46 GB / 656 s |
| its ~204k-load loop: iterations over 10 ms | 328 (145.8 s, worst 50.2 s) | 176 (139.8 s, worst 10.8 s) |
| stall-free time (loop total minus those) | 508.2 s, 2.49 ms/load | 475.2 s, 2.33 ms/load |

The loop rows ran base and fixed in parallel on 4 cores. The remaining stalls are not sites: the file's case tables
hold 590 MB with no `load` at all, against the reference's 89 MB peak for the whole file.

## COMMITS

```
b9b1a6b Index errors name the indexed value as getobjname does (probe-found)
a3d3d42 Grader gates: no duplicate D.manifest line, builtin inventory checked against the reference (EigenLua#21)
55d6d2f Sites of loaded chunks live with the chunk, not in lr_st.sites (EigenLua#29)
f6aae06 Generic for: the closing value closes at the loop's 'end' line (EigenLua#22)
82755d4 Library argument errors: random, getinfo options, setupvalue, metamethod names; errno gap (EigenLua#28)
14a6bbb One id space for tostring and %p: tables, functions, threads, strings (EigenLua#27)
9eb76b2 xpcall's message handler runs at the raise point, before pending __close (EigenLua#26)
803a24a Hex floats round once, at the result's precision, subnormals included (EigenLua#25)
3de271b load reader counts: lookahead only past a name, check_readonly at the '=', attribute after '>' (EigenLua#24)
(plus the final commit: LEDGER, README, GAPS, this report)
```

## Tests

`bash tests/parse_all.sh`: `parsed=131/131`.
`bash tests/run.sh` (tail):
```
ROW D xpcall_handler_frame.lua MATCH rc=0
SUMMARY S=23/23 D=108/108 fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=131 assert=trusted
RUN ok
```
All 31 PLANT lines are OK, including dup-manifest, builtin-missing and builtin-uncited.

## Caveats

- #29's D row cannot show the fix on stdout (`collectgarbage("count")` is out of scope); it is a regression guard
  that diverges at 79e29669 on a different bug.
- The #21 coverage check is textual: a cited row must name the builtin (`lib.k` or `"k"`) in code. It shows that
  coverage is declared and reachable, not that every value is checked.
- num_hexfloat_subnormal.lua takes about 7 s on the candidate against a 20 s row budget.
- No new trigger of EigenScript#1661 was found. A `grep -q` in a pipe under `pipefail` made the first version of the
  builtin gate flaky (the first grep is killed by SIGPIPE); it was fixed before the commit.
- Out of scope: binary chunks, `getinfo` of another coroutine, `getinfo` fields beyond 'S'/'l', and an upstream issue
  for no-errno (EigenScript is outside this session's repository scope).
