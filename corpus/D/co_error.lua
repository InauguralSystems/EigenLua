-- surface: coroutines error inside a coroutine
local co = coroutine.create(function()
  error("co-boom")
end)
local ok, err = coroutine.resume(co)
print(ok)
print(type(err) == "string" and string.find(err, "co-boom", 1, true) ~= nil)
print(coroutine.status(co))
