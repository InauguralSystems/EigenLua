-- surface: xpcall with a handler
local ok, err = xpcall(function() error("zz") end, function(e)
  return "handled:" .. string.match(e, "([^:]+)$")
end)
print(ok, err)
ok, err = xpcall(function() error({1, 2}) end, function(e)
  return e[1] + e[2]
end)
print(ok, err)
