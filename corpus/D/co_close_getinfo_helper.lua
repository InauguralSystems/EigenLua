-- surface: coroutine.close cuts debug frames at __close, not at a fixed level
local function levels()
  for i = 1, 4 do
    local info = debug.getinfo(i)
    print(i, info and info.what or "nil")
  end
end
local co = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function() levels() end})
  coroutine.yield()
end)
print(coroutine.resume(co))
print(coroutine.close(co))
