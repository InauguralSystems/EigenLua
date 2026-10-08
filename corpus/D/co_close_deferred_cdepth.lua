-- surface: lua_closethread's C-stack level while running deferred close methods
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

local victim = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function() end})
  error("victim", 0)
end)
coroutine.resume(victim)

local host = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function()
    pcall(coroutine.close, victim)
    print(count())
  end})
  error("host", 0)
end)
coroutine.resume(host)
coroutine.close(host)
