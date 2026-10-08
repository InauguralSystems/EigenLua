-- surface: lcode.c folds integer negative zero but preserves floating negative zero as an RK key
local function name(f)
  local ok, msg = pcall(f)
  print(ok, msg:match("(%(field .-%))$"))
end
local t = {}
name(function() return t[-0].x end)
local Z <const> = 0
name(function() return t[-Z].x end)
name(function() return t[-0.0].x end)
