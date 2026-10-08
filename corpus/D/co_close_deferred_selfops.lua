-- surface: deferred closes have the closed coroutine's running/C-call state
local co
co = coroutine.create(function()
  local a <close> = setmetatable({}, {__close = function()
    print("status self", coroutine.status(co))
    print("yield", pcall(coroutine.yield))
    print("resume self", pcall(coroutine.resume, co))
    print("close self", pcall(coroutine.close, co))
  end})
  error("e0", 0)
end)
coroutine.resume(co)
print("close", coroutine.close(co))
