-- surface: generic-for calls the iterator returned by pairs with nil state
local ok, message = pcall(function()
  for _ in pairs({answer = 42}), nil do end
end)
print(ok, message)
