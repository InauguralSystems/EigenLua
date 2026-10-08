-- surface: the string metatable's observable arithmetic coercion functions
local mt = getmetatable("")
local keys = {}
for key in pairs(mt) do keys[#keys + 1] = key end
table.sort(keys)
print(table.concat(keys, " "))
print(type(mt.__add), mt.__add("1", 2))
