-- surface: replacing a string arithmetic metamethod affects the operator
local mt = getmetatable("")
local old = mt.__add
mt.__add = function(a, b) return "override:" .. a .. ":" .. b end
print("1" + 2, 2 + "1")
mt.__add = old
print("1" + 2)
