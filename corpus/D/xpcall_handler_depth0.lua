-- surface: xpcall's emergency handler budget at C-call depth zero
local calls, overflow_at = 0
local function handler(err)
  calls = calls + 1
  if err == "C stack overflow" then overflow_at = calls end
  error("again", 0)
end
xpcall(function() error("start", 0) end, handler)
print(calls, overflow_at)
