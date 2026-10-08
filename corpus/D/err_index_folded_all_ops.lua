-- surface: lcode.c constfolding/rawarith covers every arithmetic and bitwise opcode used to select OP_GETI
local function name(label, f)
  local ok, msg = pcall(f)
  print(label, ok, msg:match("(%(field .-%))$"))
end
local function nofold(label, f)
  local ok, msg = pcall(f)
  print(label, ok, msg:match("(%(field .-%))$") == "(field 'integer index')")
end
local t = {}
local P <const> = 2 ^ 4

-- ADD SUB MUL MOD POW DIV IDIV, including the previously missed mixed trees.
name("add", function() return t[1 + 2].x end)
name("sub", function() return t[5 - 2].x end)
name("mul", function() return t[2 * 3].x end)
name("mod", function() return t[7 % 4].x end)
name("pow", function() return t[(2 ^ 3) | 0].x end)
name("pow-idiv", function() return t[2 ^ 3 // 1 | 0].x end)
name("pow-const", function() return t[P & 31].x end)
name("div", function() return t[(6 / 3) | 0].x end)
name("div-tree", function() return t[(7 / 2 * 2) | 0].x end)
name("idiv", function() return t[7 // 2].x end)

-- BAND BOR BXOR SHL SHR UNM BNOT.  SHR cases require luaV_shiftl's
-- unsigned right shift rather than EigenScript's signed primitive shift.
name("band", function() return t[7 & 3].x end)
name("bor", function() return t[1 | 4].x end)
name("bxor", function() return t[7 ~ 5].x end)
name("shl", function() return t[1 << 4].x end)
name("shr-neg1", function() return t[-1 >> 63].x end)
name("shr-neg256", function() return t[-256 >> 56].x end)
name("shr-neg8", function() return t[-8 >> 61].x end)
name("shift-reverse", function() return t[16 << -2].x end)
name("shift-wide", function() return t[1 >> 64].x end)
name("unm", function() return t[-(-3)].x end)
name("bnot", function() return t[~(-6)].x end)

-- validop/constfolding refusal controls: zero divisors, lossy bitwise
-- conversion, float zero (including -0.0), and NaN stay RK operands.
nofold("no-mod-zero", function() return t[3 % 0].x end)
nofold("no-idiv-zero", function() return t[3 // 0].x end)
nofold("no-div-zero", function() return t[3 / 0].x end)
nofold("no-bit-loss", function() return t[3.5 & 1].x end)
nofold("no-float-zero", function() return t[1.0 - 1].x end)
nofold("no-neg-zero", function() return t[-0.0].x end)
nofold("no-nan", function() return t[(-1) ^ 0.5].x end)

-- OP_GETI's operand is one byte; folded integers outside 0..255 remain RK.
name("geti-zero", function() return t[0 + 0].x end)
name("geti-255", function() return t[250 + 5].x end)
name("no-geti-neg", function() return t[1 - 2].x end)
name("no-geti-256", function() return t[255 + 1].x end)
