-- surface: a protected error inside a coroutine closes before pcall returns
local co = coroutine.create(function()
  local ok, e = pcall(function()
    local x <close> = setmetatable({}, {__close = function(_, err) print("close x", err) end})
    error("inner", 0)
  end)
  print("after pcall", ok, e)
  coroutine.yield(1)
  return 2
end)
print(coroutine.resume(co))
print(coroutine.resume(co))
print(coroutine.status(co))
print(coroutine.close(co))
