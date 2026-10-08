-- surface: deferred closes run as the closed coroutine, not its closer
for _, mode in ipairs{"yield", "error"} do
  local co
  co = coroutine.create(function()
    local a <close> = setmetatable({}, {__close = function(_, e)
      print(mode, "status", coroutine.status(co), "running is co", coroutine.running() == co)
      print(mode, "close self", pcall(coroutine.close, co))
    end})
    if mode == "yield" then coroutine.yield() else error("e0", 0) end
  end)
  coroutine.resume(co)
  print(mode, coroutine.close(co))
end
