-- surface: one live pcall consumes one level of xpcall's emergency C stack
local calls, overflow_at = 0
local function handler(err)
  calls = calls + 1
  if err == "C stack overflow" then overflow_at = calls end
  error("again", 0)
end
pcall(function() xpcall(function() error("start", 0) end, handler) end)
print(calls, overflow_at)
