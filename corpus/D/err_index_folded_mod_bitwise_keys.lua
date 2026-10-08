-- surface: getobjname classifies modulo and bitwise constants folded by lcode.c as OP_GETI
local function name(f)
  local ok, msg = pcall(f)
  print(ok, msg:match("(%(field .-%))$"))
end
local t = {}
name(function() return t[7 % 3].x end)
name(function() return t[-7 % 3].x end)
name(function() return t[3 & 1].x end)
name(function() return t[1 | 2].x end)
name(function() return t[3 ~ 1].x end)
name(function() return t[1 << 3].x end)
name(function() return t[16 >> 2].x end)
name(function() return t[~(-6)].x end)
name(function() return t[3.0 & 1].x end)
name(function() return t[3.5 & 1].x end) -- no lossless integer conversion
name(function() return t[3 % 0].x end) -- modulo by zero is not folded
