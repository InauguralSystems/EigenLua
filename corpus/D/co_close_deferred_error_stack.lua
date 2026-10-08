-- surface: a failed deferred __close does not leak frames into the caller
local co = coroutine.create(function()
  local b <close> = setmetatable({}, {__close = function() error("berr", 0) end})
  error("e0", 0)
end)
coroutine.resume(co)
print(coroutine.close(co))
print(debug.getinfo(2, "S").what, debug.getinfo(3) == nil)
print(debug.traceback("tb"))
