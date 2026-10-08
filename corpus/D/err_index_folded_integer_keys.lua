-- surface: getobjname classifies integer arithmetic, unary minus, and integer division folded by lcode.c as OP_GETI
local function name(f)
  local ok, msg = pcall(f)
  print(ok, msg:match("(%(field .-%))$"))
end
local t = {}
local N <const> = 5
name(function() return t[N].x end)
name(function() return t[1 + 1].x end)
name(function() return t[-(-1)].x end)
name(function() return t[3 // 1].x end)
name(function() return t[(2 * 3) - 1].x end)
