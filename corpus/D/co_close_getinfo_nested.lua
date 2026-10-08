-- surface: a nested coroutine.close restores the outer close-frame cutoff
local function levels()
  for i = 1, 4 do
    local info = debug.getinfo(i)
    print(i, info and info.what or "nil")
  end
end
local inner = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function()
    print("inner-close")
    levels()
  end})
  coroutine.yield()
end)
assert(coroutine.resume(inner))
local outer = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function()
    print("inner", coroutine.close(inner))
    levels()
  end})
  coroutine.yield()
end)
print(coroutine.resume(outer))
print(coroutine.close(outer))
