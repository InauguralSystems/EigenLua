-- surface: table.move's overflow checks (ltablib.c tmove: f > 0 or e < LUA_MAXINTEGER + f; t <= LUA_MAXINTEGER - n + 1) are int64 arithmetic on a C constant, computed exactly; the moves' first accesses through __index/__newindex
-- the overflow checks of ltablib.c tmove, with values a double holds exactly
local minI = math.mininteger
local function try(...) print(pcall(table.move, ...)) end
try({}, minI, -1, 1)
try({}, minI, -2, 2)
try({}, minI, 0, 1)
try({}, -2^62, 2^62, 1)
print((pcall(table.move, {}, 1, 2, 2^62 + (2^62 - 2048))))
try({}, 0, 2^62, 2^62)
local a = setmetatable({}, {__index = function(_, k) print("get", k) end,
                            __newindex = function(_, k) print("set", k) error("stop") end})
try(a, minI, -2, 0)
try(a, minI, -2, 1)
try(a, -5, -3, -7)
try(a, 2^62, 2^62 + 2^61, 2^61)
local t = table.move({1, 2, 3, 4, 5}, 2, 4, 1)
print(t[1], t[2], t[3], t[4], t[5])
t = table.move({1, 2, 3, 4, 5}, 1, 3, 3)
print(t[1], t[2], t[3], t[4], t[5])
