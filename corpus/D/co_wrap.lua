-- surface: coroutines wrap
local f = coroutine.wrap(function(x)
  local y = coroutine.yield(x .. "-y")
  return y .. "-z"
end)
print(f("a"))
print(f("b"))
