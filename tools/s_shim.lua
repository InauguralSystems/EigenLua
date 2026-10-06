_U = true
local __n = 0
local __reported = false
local __real_assert = assert
local __real_exit = os.exit
local function __report()
  if __reported then return end
  __reported = true
  io.stderr:write("EIGENLUA-ASSERTS:", tostring(__n), "\n")
  io.stderr:flush()
end
function os.exit(code, close)
  __report()
  return __real_exit(code, close)
end
function assert(...)
  __n = __n + 1
  if select(1, ...) then
    return ...
  end
  local nargs = select("#", ...)
  if nargs == 0 then
    return __real_assert()
  end
  if nargs == 1 then
    error("assertion failed!", 2)
  end
  local msg = select(2, ...)
  if type(msg) ~= "string" then
    error(msg, 0)
  end
  error(msg, 2)
end
local __path = "__PATH__"
arg = {[0] = __path}
local __chunk, __err = loadfile(__path)
if not __chunk then
  io.stderr:write(tostring(__err), "\n")
  __report()
  __real_exit(1)
end
local __ok, __res = xpcall(__chunk, function(e) return e end)
__report()
if not __ok then
  io.stderr:write(tostring(__res), "\n")
  io.stderr:flush()
  __real_exit(1)
end
__real_exit(0)
