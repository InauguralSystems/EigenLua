-- surface: os.exit(code, true) closes the state (loslib.c os_exit, lua_close): the main thread's pending to-be-closed variables close innermost first with no error, an error in one is passed to the next (luaD_closeprotected), pcall does not stop the exit, and a coroutine's variables are not closed
local function closer(name)
  return setmetatable({}, {__close = function(_, e) print("closed", name, e) end})
end
local co = coroutine.wrap(function()
  local c <close> = closer("in coroutine")
  coroutine.yield()
end)
co()
do
  local a <close> = closer("a")
  local function f()
    local b <close> = closer("b")
    for _ in function() return nil end, nil, nil, closer("for") do end
    local x <close> = setmetatable({}, {__close = function() print("x raises") error("in x") end})
    local co2 = coroutine.wrap(function()
      local d <close> = closer("d, in a running coroutine")
      pcall(os.exit, 3, true)
      print("not reached")
    end)
    co2()
  end
  f()
end
print("not reached")
