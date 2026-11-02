-- surface: coroutine.close runs a suspended coroutine's closes at the closer's C level, before and after a close error (lua_closethread)
local function count()
  local calls, overflow_at = 0
  local function handler(err)
    calls = calls + 1
    if err == "C stack overflow" then overflow_at = calls end
    error("again", 0)
  end
  xpcall(function() error("start", 0) end, handler)
  return calls, overflow_at
end
local function lv()
  local out = {}
  for i = 1, 4 do
    local info = debug.getinfo(i, "S")
    out[i] = info and info.what or "nil"
  end
  return table.concat(out, ",")
end
local co = coroutine.create(function()
  local a <close> = setmetatable({}, {__close = function(_, e) print("a", e, lv(), count()) end})
  local function deep()
    local b <close> = setmetatable({}, {__close = function(_, e)
      print("b", e, lv(), count())
      local function deeper() error("berr", 0) end
      deeper()
    end})
    coroutine.yield(1)
  end
  deep()
end)
print(coroutine.resume(co))
print(coroutine.close(co))
print("main", lv(), count())
print(debug.traceback("tb"))
