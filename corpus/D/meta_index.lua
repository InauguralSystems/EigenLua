-- surface: metatables __index
local base = {x = 10, y = 20}
local t = setmetatable({y = 2}, {__index = base})
print(t.x, t.y, tostring(t.z))
local u = setmetatable({}, {__index = function(_, key) return "miss:" .. key end})
print(u.foo)
print(rawget(t, "x"))
