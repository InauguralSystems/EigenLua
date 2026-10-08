-- surface: lstrlib arithmetic trymt fallback and non-recursive failures
local T = setmetatable({}, {__add = function() return "T" end})
print(pcall(function() return T + "1" end))
print(pcall(function() return "1" + T end))
print(pcall(function() return "abc" + T end))
print(pcall(function() return "abc" + 1 end))
print(pcall(function() return -"abc" end))

getmetatable("").__add = nil
print(pcall(function() return "1" + 2 end))

-- self-identical RHS metamethod re-dispatches, as lstrlib trymt does
local mt = getmetatable("")
local T = setmetatable({}, {__add = mt.__add})
print(pcall(function() return "abc" + T end))
print(pcall(function() return T + "abc" end))
print(pcall(function() return T + 1 end))
print(pcall(function() return "1" + T end))
local U = setmetatable({}, {__add = function(a, b) return mt.__add(a, 5) end})
print(pcall(function() return "abc" + U end))
print(pcall(function() return "3" + U end))
local saved = mt.__add
mt.__add = nil
local s = "abc"
print(pcall(function() return s + 1 end))
print(pcall(function() return "x" + T end))
print(pcall(function() return T + "x" end))
