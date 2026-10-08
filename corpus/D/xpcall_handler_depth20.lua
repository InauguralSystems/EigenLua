-- surface: twenty live pcalls consume twenty levels of xpcall's emergency C stack
local calls, overflow_at = 0
local function handler(err)
  calls = calls + 1
  if err == "C stack overflow" then overflow_at = calls end
  error("again", 0)
end
local function enter(n)
  if n == 0 then return xpcall(function() error("start", 0) end, handler) end
  return pcall(enter, n - 1)
end
enter(20)
print(calls, overflow_at)
