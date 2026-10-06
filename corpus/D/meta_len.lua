-- surface: metatables __len
local t = setmetatable({1, 2, 3, 4}, {__len = function() return 2 end})
print(#t)
print(rawlen(t))
