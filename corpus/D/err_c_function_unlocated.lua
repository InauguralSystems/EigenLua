-- surface: an error raised by the runtime while a C library function runs (next, the sort comparison, the ipairs iterator's index, math.max/min's compare) carries no position: ldebug.c luaG_runerror adds one only when the running function is Lua
print(pcall(function() return next({}, "nokey") end))
print(pcall(function() local t = {3, 1, "x", 2} table.sort(t) end))
print(pcall(function() for i, v in ipairs(5) do end end))
print(pcall(function() return math.max(1, {}) end))
print(pcall(function() return math.min("a", 1) end))
