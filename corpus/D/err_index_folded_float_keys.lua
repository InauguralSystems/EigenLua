-- surface: folded float keys retain OP_GETTABLE names, and unsafe/non-foldable numeric expressions remain unnamed RK keys
local function name(f)
  local ok, msg = pcall(f)
  print(ok, msg:match("(%(field .-%))$"))
end
local t = {}
name(function() return t[1 + 1].x end) -- integer-folding control
name(function() return t[1.0 + 1].x end)
name(function() return t[3 / 1].x end)
name(function() return t[3 / 2].x end)
name(function() return t[-0.0].x end) -- lcode.c must not fold negative zero
local k = 2
name(function() return t[k].x end) -- a non-const local is not folded
