# The second independent review's population

These files are the differential population that the second independent review of the
move to the next runtime wrote and ran against the reference Lua. They were added
by the requester of that review, unchanged, so that the next round is measured on
expressions that no builder of the number layer chose.

- `gen.py <class>` prints one Lua file for each of five classes: `arith` (integer
  arithmetic that wraps), `text` (a number's text), `keys` (table keys), `nil`,
  `kinds` (the kind of a result). Each expression is written three ways: with
  literals inside a function, with its operands as parameters, and through `load`.
- `mathinf.lua`, `fdiv.lua`, `forlim.lua`: real infinities and NaN through the math
  library, floor division and remainder, and a numeric `for` loop's limits.

On the head the review read (`f6911e8`), run on the candidate and on the reference:
`arith` 4 expressions differ (shifts of values near `math.maxinteger`), `text` 11
(`%q` of an integral float), `keys` 0, `nil` 0 real, `kinds` 4 (three of them
`math.fmod`), and of the 80 expressions with a non-finite value 24 differ.
