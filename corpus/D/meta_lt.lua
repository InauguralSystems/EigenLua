-- surface: metatables __lt
local mt = {__lt = function(a, b) return a.n < b.n end}
local a = setmetatable({n = 1}, mt)
local b = setmetatable({n = 2}, mt)
print(a < b)
print(b < a)
print(a <= b)
