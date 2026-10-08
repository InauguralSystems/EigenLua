-- surface: repeated errors in an xpcall message handler reach the emergency C-stack limit
local calls, overflow_at = 0
local function handler(err)
  calls = calls + 1
  if err == "C stack overflow" or
     (type(err) == "string" and err:match("C stack overflow", 1, true)) then
    overflow_at = calls
  end
  error("again")
end
local ok, err = xpcall(function() error("start") end, handler)
print(ok, err, calls, overflow_at)
