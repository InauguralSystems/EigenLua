-- surface: each deferred __close starts with a restored caller stack
local function lv()
  local out = {}
  for i = 1, 4 do
    local info = debug.getinfo(i, "S")
    out[i] = info and info.what or "nil"
  end
  return table.concat(out, ",")
end
local co = coroutine.create(function()
  local a <close> = setmetatable({}, {__close = function(_, err)
    local r = lv()
    print("a", err, r)
  end})
  local b <close> = setmetatable({}, {__close = function() error("berr", 0) end})
  error("e0", 0)
end)
coroutine.resume(co)
print(coroutine.close(co))
local r = lv()
print("main", r)
