-- surface: wrap error closes run from lua_closethread and cannot yield
local w = coroutine.wrap(function()
  local z <close> = setmetatable({}, {__close = function(_, e)
    print("close", e, coroutine.isyieldable())
    print("yield", pcall(coroutine.yield, "bad"))
  end})
  error("we", 0)
end)
print("wrap", pcall(w))
