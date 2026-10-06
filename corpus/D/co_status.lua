-- surface: coroutines status
local co = coroutine.create(function()
  coroutine.yield(1)
  return 2
end)
print(coroutine.status(co))
local ok, v = coroutine.resume(co)
print(ok, v, coroutine.status(co))
ok, v = coroutine.resume(co)
print(ok, v, coroutine.status(co))
ok, v = coroutine.resume(co)
print(ok, coroutine.status(co))
