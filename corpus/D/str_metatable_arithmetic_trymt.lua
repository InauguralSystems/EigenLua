-- surface: lstrlib arithmetic trymt fallback and non-recursive failures
local T = setmetatable({}, {__add = function() return "T" end})
print(pcall(function() return T + "1" end))
print(pcall(function() return "1" + T end))
print(pcall(function() return "abc" + T end))
print(pcall(function() return "abc" + 1 end))
print(pcall(function() return -"abc" end))

getmetatable("").__add = nil
print(pcall(function() return "1" + 2 end))
