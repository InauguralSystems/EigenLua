-- surface: print writes each value as it converts it (lbaselib.c luaB_print), so a failing __tostring leaves the values before it on stdout
-- print writes each value as it converts it (lbaselib.c luaB_print)
local bad = setmetatable({}, {__tostring = function() return {} end})
print(pcall(print, "first", 2, bad, "never"))
print(pcall(print, "a", setmetatable({}, {__tostring = function() error("boom") end})))
