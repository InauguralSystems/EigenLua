-- surface: a __close called by coroutine.close has no caller at debug level 2
local co = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function()
    print(debug.getinfo(1) ~= nil, debug.getinfo(2) == nil)
  end})
  coroutine.yield()
end)
print(coroutine.resume(co))
print(coroutine.close(co))
