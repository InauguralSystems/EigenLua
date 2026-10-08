-- surface: a coroutine error leaves to-be-closed variables pending until coroutine.close
local closed = 0
local co = coroutine.create(function()
  local x <close> = setmetatable({}, {__close = function(_, err)
    closed = closed + 1
    print("closing", type(err), tostring(err):match("boom", 1, true) ~= nil)
  end})
  error("boom")
end)
local ok, err = coroutine.resume(co)
print("resume", ok, closed, tostring(err):match("boom", 1, true) ~= nil)
local cok, cerr = coroutine.close(co)
print("close", cok, closed, tostring(cerr):match("boom", 1, true) ~= nil)
