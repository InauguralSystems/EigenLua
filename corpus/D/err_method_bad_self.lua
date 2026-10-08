-- surface: luaL_argerror includes the argument reason for a bad method self
local t = {f = string.rep}
local ok, err = pcall(function() return t:f(2) end)
print(ok, err:match("calling 'f' on bad self %(string expected, got table%)") ~= nil)
