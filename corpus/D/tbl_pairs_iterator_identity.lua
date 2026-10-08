-- surface: pairs returns the global next function itself
local t = {answer = 42}
local iter, state, initial = pairs(t)
print(iter == next, state == t, initial == nil)
