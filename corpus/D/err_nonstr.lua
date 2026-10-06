-- surface: error values that are not strings
local t = {k = "v"}
local ok, err = pcall(function() error(t) end)
print(ok, err == t, err.k)
ok, err = pcall(function() error(false) end)
print(ok, tostring(err))
ok, err = pcall(function() error(42) end)
print(ok, err)
ok, err = pcall(function() error(nil) end)
print(ok, tostring(err))
