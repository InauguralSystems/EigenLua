-- surface: coroutines resume and yield passing values both ways
local co = coroutine.create(function(a)
  local b = coroutine.yield(a + 1)
  return b * 2
end)
local ok, v = coroutine.resume(co, 10)
print(ok, v)
ok, v = coroutine.resume(co, 7)
print(ok, v)
print(coroutine.status(co))
