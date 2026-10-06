-- surface: metatables __eq
local mt = {__eq = function(a, b) return a.n == b.n end}
local a = setmetatable({n = 3}, mt)
local b = setmetatable({n = 3}, mt)
local c = setmetatable({n = 4}, mt)
print(a == b)
print(a == c)
print(rawequal(a, b))
