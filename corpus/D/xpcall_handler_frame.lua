-- surface: an xpcall message handler runs at the error point (ldo.c luaG_errormsg): for an error raised by Lua code, level 2 is the erring Lua function at the erring line, with no C level between; for error(), level 2 is error itself
local function line2(m) return debug.getinfo(2, "Sl").currentline .. " " .. debug.getinfo(2, "S").what end
local function f(x)
  local y = x + nil
end
print(xpcall(f, line2, 1))
print(xpcall(function()
  local t = nil
  return t.x
end, line2))
print(xpcall(function() error("e") end, line2))
local function deep(n)
  if n == 0 then local z = {} .. n end
  deep(n - 1)
end
print(xpcall(deep, line2, 5))
print(xpcall(deep, function(m)
  local tb = debug.traceback(m, 2)
  local n = 0
  for l in tb:gmatch("\n\t[^\n]*:13: ") do n = n + 1 end
  return n
end, 3))
