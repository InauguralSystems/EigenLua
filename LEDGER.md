# EigenLua front end: divergence ledger (round 1)

Every row of `tools/grade.sh --candidate bin/eigenlua --tier all` that is not PASS/MATCH, classified.
Graded on EigenScript v0.44.0 (release asset `eigenscript-linux-x86_64`, sha256 `145986c2…89ea`) against
PUC-Rio Lua 5.4.9. Grader verdict: `SUMMARY S=0/23 D=13/47 fail=23 diverge=12 hang=0 crash=0 unsupported=22
examined=70 assert=untrusted`.

Classes: `front-end bug` (fixed here), `unsupported` (the front end refuses the construct: exit 3,
`EIGENLUA-UNSUPPORTED: <construct> at <file>:<line>`), `EigenScript gap` (the owner's direct-value-mapping decision
maps the Lua value onto a native value that cannot carry it; reproducer under `gaps/`), `unspecified`.

Evidence was gathered by running each row directly, outside the grader: `.ref/bin/lua <row>` against
`bin/eigenlua <row>`, full stdout diffed. For an UNSUPPORTED row, the stdout the candidate printed before it exited
was diffed against the same number of reference lines, so a front-end bug hiding before the refusal would show.
None did: every divergence in those prefixes is one of the gap classes below.

## Gap reproducers

| file | gap | EigenScript#1286 row |
|---|---|---|
| `gaps/no-boolean.eigs` | no boolean type: `1 == 1` is `1` of type `num`; `false` and `0` are one value, and so are `true` and `1` | Booleans folded into another type |
| `gaps/no-float-subtype.eigs` | one double: `1.0` prints `1`, `3 / 1` prints `3`; `math.type` cannot answer `float` for an integral value | One overloaded number type |
| `gaps/no-int64.eigs` | no 64-bit integer: `2^53 + 1` silently stays `2^53`; no wrap at `maxinteger` | One overloaded number type |
| `gaps/no-nonfinite.eigs` | no inf/nan: `1 / 0` raises, overflow saturates at `1e308` silently | One overloaded number type |
| `gaps/nul-in-string.eigs` | NUL-terminated strings: `chr of 0` raises, `str_from_bytes` stops at a NUL | The string model |
| `gaps/call-depth.eigs` | call depth about 5000 frames (about 2000 Lua levels in EigenLua) vs Lua's about 200000 | none (VM limit) |

How the front end meets each gap:
- booleans, the float subtype and int64 map directly (owner decision) and DIVERGE where a program prints them;
- inf/nan, NUL bytes and a call-depth overflow have no nearest native value: EigenLua exits 3
  (`EIGENLUA-UNSUPPORTED`) instead of printing a stand-in (`1e308`, a truncated string) or a Lua `stack overflow`
  that Lua itself would not raise.

## Tier S (23 rows, all `FAIL assert-untrusted`)

The grader ran `corpus/D/assert_semantics.lua` on the candidate first, and its stdout differs at line 1:
`false 2 boolean:false string:assertion failed!` (ref) vs `false 2 number:0 string:assertion failed!` (cand).
`pcall` returns `false`, which maps to `0` of type `number`. With `assert` untrusted, the grader runs no S row on the
candidate, so these rows say nothing about the files themselves. The probe also exits 3 at line 39 on `string.match`,
and its `zero` row is wrong as well: `assert(0)` raises, because `0` and `false` are one value. Both are boolean-gap
consequences, or unsupported, and neither is a front-end bug.

| row | tier | verdict | class | cause | evidence |
|---|---|---|---|---|---|
| bitwise.lua | S | FAIL | EigenScript gap | assert-trust probe diverges: no boolean type | probe diff line 1 (above); `gaps/no-boolean.eigs` |
| calls.lua | S | FAIL | EigenScript gap | same | same |
| closure.lua | S | FAIL | EigenScript gap | same | same |
| constructs.lua | S | FAIL | EigenScript gap | same | same |
| coroutine.lua | S | FAIL | EigenScript gap | same | same |
| cstack.lua | S | FAIL | EigenScript gap | same | same |
| db.lua | S | FAIL | EigenScript gap | same | same |
| errors.lua | S | FAIL | EigenScript gap | same | same |
| events.lua | S | FAIL | EigenScript gap | same | same |
| gc.lua | S | FAIL | EigenScript gap | same | same |
| gengc.lua | S | FAIL | EigenScript gap | same | same |
| goto.lua | S | FAIL | EigenScript gap | same | same |
| literals.lua | S | FAIL | EigenScript gap | same | same |
| locals.lua | S | FAIL | EigenScript gap | same | same |
| math.lua | S | FAIL | EigenScript gap | same | same |
| nextvar.lua | S | FAIL | EigenScript gap | same | same |
| pm.lua | S | FAIL | EigenScript gap | same | same |
| sort.lua | S | FAIL | EigenScript gap | same | same |
| strings.lua | S | FAIL | EigenScript gap | same | same |
| tpack.lua | S | FAIL | EigenScript gap | same | same |
| utf8.lua | S | FAIL | EigenScript gap | same | same |
| vararg.lua | S | FAIL | EigenScript gap | same | same |
| verybig.lua | S | FAIL | EigenScript gap | same | same |

## Tier D: DIVERGE (12 rows)

Every line that differs was checked. The only differences are `true`/`false` printed as `1`/`0`, truthiness of `0`,
integral floats printed as integers, and 64-bit integer values.

| row | tier | verdict | class | cause | evidence |
|---|---|---|---|---|---|
| err_nonstr.lua | D | DIVERGE | EigenScript gap | `false`/`true` print as `0`/`1`; every other field matches (`v`, `42`, `nil`) | 4 lines differ only in booleans; `gaps/no-boolean.eigs` |
| int_maxinteger.lua | D | DIVERGE | EigenScript gap | `math.maxinteger` is 2^63-1, not a double; its nearest double is 2^63, which prints as a float and is `math.type` `float` | line 1 `9223372036854775807` vs `9.2233720368548e+18`; `gaps/no-int64.eigs`; lines 4-6 booleans |
| int_one_vs_one.lua | D | DIVERGE | EigenScript gap | `1.0` prints `1`, `math.type(1.0)` is `integer`, `1 + 0.0` prints `1` | `gaps/no-float-subtype.eigs`; line 5 boolean |
| int_past53.lua | D | DIVERGE | EigenScript gap | `(1 << 53) + 1` stays `9007199254740992`; `two53 + 0.0` is `integer` | `gaps/no-int64.eigs`, `gaps/no-float-subtype.eigs`; lines 3-4 booleans |
| int_wrap.lua | D | DIVERGE | EigenScript gap | `maxinteger + 1` does not wrap to `mininteger` (and `maxinteger` itself is 2^63) | `gaps/no-int64.eigs` |
| meta_eq.lua | D | DIVERGE | EigenScript gap | `__eq` results `true/false/false` print `1/0/0` | 3 lines, booleans only; `gaps/no-boolean.eigs` |
| meta_lt.lua | D | DIVERGE | EigenScript gap | `__lt`/`__le` results and `pcall` status print as `1`/`0` | 6 lines, booleans only; `<=` with only `__lt` raises in the candidate as Lua 5.4 requires (line 4 `0 0` = `false false`) |
| str_case_rev_sub.lua | D | DIVERGE | EigenScript gap | `== ""` comparisons print `1` | lines 3, 5, 7, 8 differ in booleans only; all string results match |
| tbl_int_float_key.lua | D | DIVERGE | EigenScript gap | `t[1] == t[1.0]` prints `1` | line 3 only |
| tbl_len_border.lua | D | DIVERGE | EigenScript gap | `isborder(...)` prints `1` | line 3 only; every `#t` matches |
| tbl_next_pairs.lua | D | DIVERGE | EigenScript gap | `next(h) == nil` prints `1` | lines 4-5 booleans; sorted traversals match |
| tbl_nil_holes.lua | D | DIVERGE | EigenScript gap | `isborder(...)` prints `1` | lines 1, 3, 5 booleans only |

## Tier D: UNSUPPORTED (22 rows)

Each row exits 3 with the message shown. "Prefix" is the stdout printed before the exit, compared with the
reference's first lines.

| row | tier | verdict | class | cause | evidence |
|---|---|---|---|---|---|
| assert_semantics.lua | D | UNSUPPORTED | unsupported | `string.match` (Lua patterns not implemented) | `EIGENLUA-UNSUPPORTED: string.match at assert_semantics.lua:39`; prefix diverges in booleans only (`gaps/no-boolean.eigs`, incl. `assert(0)` raising) |
| co_error.lua | D | UNSUPPORTED | unsupported | coroutines not implemented | `coroutine.create at co_error.lua:2` |
| co_resume_yield.lua | D | UNSUPPORTED | unsupported | coroutines | `coroutine.create at co_resume_yield.lua:2` |
| co_status.lua | D | UNSUPPORTED | unsupported | coroutines | `coroutine.create at co_status.lua:2` |
| co_wrap.lua | D | UNSUPPORTED | unsupported | coroutines | `coroutine.wrap at co_wrap.lua:2` |
| err_level.lua | D | UNSUPPORTED | unsupported | `string.match` | `string.match at err_level.lua:10`; prefix `0` vs `false` (boolean gap). The positions themselves match: a copy that prints `err` instead of matching it prints `el.lua:3: from-inner` and `el.lua:15: from-caller` on both arms |
| err_pcall.lua | D | UNSUPPORTED | unsupported | `string.match` | `string.match at err_pcall.lua:5`; prefix booleans only |
| err_xpcall.lua | D | UNSUPPORTED | unsupported | `string.match` inside the handler | `string.match at err_xpcall.lua:3` |
| goto_stmt.lua | D | UNSUPPORTED | unsupported | `goto`/labels refused by the front end | `goto at goto_stmt.lua:3` |
| num_print.lua | D | UNSUPPORTED | EigenScript gap | `1/0` has no finite double; EigenLua refuses rather than print `1e+308` | `non-finite number (inf/nan: EigenScript has none) at num_print.lua:7`; `gaps/no-nonfinite.eigs`. Once inf exists, `-0.0`, `2^53`, `2^63` still diverge (`gaps/no-float-subtype.eigs`) |
| ops_matrix.lua | D | UNSUPPORTED | unsupported | `string.format` `%.17g` (only `%d %i %s %c %%` implemented) | `string.format conversion '%.' at ops_matrix.lua:17`; prefix (25 lines) diverges in booleans only: `not 0` is `1`, `-false` is `0`, `-(-0.0)` is integer (no-boolean, no-float-subtype) |
| rng_xoshiro.lua | D | UNSUPPORTED | unsupported | `math.randomseed`/`math.random` not implemented | `math.randomseed at rng_xoshiro.lua:3` |
| str_byte_char_sub_rep.lua | D | UNSUPPORTED | EigenScript gap | `string.char(0)` needs a NUL byte in a string | `string.char(0): a NUL byte ... at str_byte_char_sub_rep.lua:2`; `gaps/nul-in-string.eigs` |
| str_classes.lua | D | UNSUPPORTED | unsupported | `string.gsub` (patterns) | `string.gsub at str_classes.lua:3` |
| str_embedded_nul.lua | D | UNSUPPORTED | EigenScript gap | the literal `"a\0b"` cannot be an EigenScript string | `string with an embedded NUL byte at str_embedded_nul.lua:2`; `gaps/nul-in-string.eigs` |
| str_find_match.lua | D | UNSUPPORTED | unsupported | `string.find` (patterns) | `string.find at str_find_match.lua:3` |
| str_format.lua | D | UNSUPPORTED | unsupported | `string.format` `%x` | `string.format conversion '%x' at str_format.lua:2`; the row also needs `load` and `%q` with a NUL (gap) |
| str_format_num.lua | D | UNSUPPORTED | unsupported | `string.format` with width/precision (`%5.2f`) | `string.format conversion '%5' at str_format_num.lua:2`; its last line (`%s` of `1.0`) would hit the float-subtype gap |
| str_gsub.lua | D | UNSUPPORTED | unsupported | `string.gsub` (patterns) | `string.gsub at str_gsub.lua:2` |
| str_high_bytes.lua | D | UNSUPPORTED | unsupported | `string.format` `%q` | `string.format conversion '%q' at str_high_bytes.lua:5`; prefix (2 lines) matches |
| str_len.lua | D | UNSUPPORTED | EigenScript gap | the literal `"a\0b"` | `string with an embedded NUL byte at str_len.lua:4`; prefix (2 lines) matches; `gaps/nul-in-string.eigs` |
| utf8_lib.lua | D | UNSUPPORTED | unsupported | `utf8` library not implemented | `utf8.char at utf8_lib.lua:2` |

## Counts

| class | rows |
|---|---|
| EigenScript gap | 39 (23 S, 12 D DIVERGE, 4 D UNSUPPORTED) |
| unsupported | 18 (D) |
| front-end bug | 0 |
| unspecified | 0 |
| unclassified | 0 |

`front-end bug` is 0 because every one found while building was fixed before this grade, not because none existed:
an off-by-limb integer printer, a missing integral-float `.0`, `%%` in Lua's `'n%%0'` message, and `assert` message positions.
