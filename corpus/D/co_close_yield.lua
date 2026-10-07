-- surface: coroutines: coroutine.close runs pending __close methods from C, so a yield inside one is an error (lcorolib.c, lua_closethread)
local co = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function() coroutine.yield("from close") end})
  coroutine.yield(1)
end)
print(coroutine.resume(co))
print(coroutine.close(co))
print(coroutine.status(co))

-- a __close that does not yield runs normally
local log = {}
local co2 = coroutine.create(function()
  local y <close> = setmetatable({}, {__close = function(_, e) log[#log + 1] = "closed:" .. tostring(e) end})
  coroutine.yield(2)
end)
print(coroutine.resume(co2))
print(coroutine.close(co2), table.concat(log, ","))

-- yield errors carry no position: the running function is the C function yield
print(pcall(coroutine.yield, 1))
print(pcall(function() coroutine.yield(1) end))
local w = coroutine.wrap(function() string.gsub("a", "a", function() coroutine.yield(1) end) end)
print(pcall(w))
