-- surface: metatables __lt and __le; in Lua 5.4 (manual 8.1) __lt no longer stands in for a missing __le
local mt = {__lt = function(a, b) return a.n < b.n end}
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 2}, mt)
print(a < b)
print(b < a)
print(a > b, b > a)
-- no __le: `<=` and `>=` are errors, not `not (b < a)`
print((pcall(function() return a <= b end)), (pcall(function() return a >= b end)))
local mt2 = {__lt = mt.__lt, __le = function(x, y) return x.n <= y.n end}
local c = setmetatable({n = 1}, mt2)
local d = setmetatable({n = 1}, mt2)
print(c <= d, c >= d, c < d)
print(math.pow == nil)
