-- surface: coroutine.close runs every pending __close of a suspended coroutine; each gets the latest error (#73, coroutine.lua:203-217)
local function func2close(f) return setmetatable({}, {__close = f}) end
local x = 0
local co = coroutine.create(function()
  local y <close> = func2close(function (self, err)
    print("y close err", err)
    x = 200
    error(200)
  end)
  local z <close> = func2close(function (self, err)
    print("z close err", err); error(111)
  end)
  coroutine.yield()
end)
coroutine.resume(co)
print("x", x)
local st, msg = coroutine.close(co)
print("close", st, msg, coroutine.status(co), x)
print("again", coroutine.close(co))
