-- surface: getobjname classifies string keys propagated from <const> locals as OP_GETFIELD after constant folding
local function name(f)
  local ok, msg = pcall(f)
  print(ok, msg:match("(%(field .-%))$"))
end
local t = {}
local K <const> = "kk"
name(function() return t[K].x end)
local A <const> = "alpha"
local B <const> = A
name(function() return t[B].x end)
