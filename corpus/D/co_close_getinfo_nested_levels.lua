-- surface: nested coroutine.close cuts only the coroutine it is closing
local function levels()
  local out = {}
  for i = 1, 4 do
    local info = debug.getinfo(i, "S")
    out[i] = info and info.what or "nil"
  end
  print(table.concat(out, ","))
end
local inner = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function() levels() end})
  coroutine.yield()
end)
assert(coroutine.resume(inner))
local outer = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function()
    local r = coroutine.close(inner)
    return r
  end})
  coroutine.yield()
end)
assert(coroutine.resume(outer))
print(coroutine.close(outer))
