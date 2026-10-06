-- Tier S prelude. tools/grade.sh drops these "--" lines, joins the rest with
-- spaces, and puts the result IN FRONT OF LINE 1 of an unmodified copy of the
-- test file, under the test's own name. So line numbers, the chunk name and
-- the stack under the test chunk are exactly those of `lua <file>`.
-- Invisibility: assert, os.exit and math.randomseed become coroutine.wrap
-- closures, i.e. C functions whose Lua body runs in another thread. A line or
-- count hook set by the test (per thread) never sees that body, and the call
-- stack shows one C frame where the real C function is. A failing assert
-- raises from the wrap with the real message; the wrap adds the caller's
-- position exactly as the real assert does (luaL_where level 1). The failed
-- coroutine is dead, so the SAME wrap closure gets a fresh one (upvalue 1),
-- because `assert(f())` fetched the closure before f's assert failed.
-- Determinism: the state-creation seed and argless math.randomseed() come
-- from time and addresses; both become a fixed seed. Argless randomseed()
-- still runs the candidate's own argless path first.
-- The count is written at lua_close (__gc) or by os.exit, once.
do
  _U = true
  local n, done, dead, w = 0, false, nil, nil
  local select, error, tostring, rawequal = select, error, tostring, rawequal
  local wrap, yield, create = coroutine.wrap, coroutine.yield, coroutine.create
  local running, resume, setupvalue = coroutine.running, coroutine.resume, debug.setupvalue
  local stderr, exit, seed = io.stderr, os.exit, math.randomseed
  local write = stderr.write
  local function report()
    if not done then
      done = true
      write(stderr, "EIGENLUA-ASSERTS:", tostring(n), "\n")
    end
  end
  local anchor = setmetatable({}, {__gc = report})
  local PRIME, pool, body = {}, {}, nil
  local function refill()
    while #pool < 16 do
      local co = create(body)
      if not resume(co, PRIME) then return end
      pool[#pool + 1] = co
    end
  end
  local function step(...)
    n = n + 1
    if (...) then
      if #pool < 16 then refill() end
      return step(yield(...))
    end
    dead = running()
    local co = pool[#pool]
    pool[#pool] = nil
    setupvalue(w, 1, co or create(body))
    refill()
    local k = select("#", ...)
    if k == 0 then error("bad argument #1 to 'assert' (value expected)", 0) end
    if k == 1 then error("assertion failed!", 0) end
    error((select(2, ...)), 0)
  end
  body = function(...)
    local _ = anchor
    if rawequal((...), PRIME) then return step(yield()) end
    return step(...)
  end
  w = wrap(body)
  w(PRIME)
  refill()
  assert = w
  os.exit = wrap(function(...) report() return exit(...) end)
  seed(20261005, 0)
  local function rs(...)
    if select("#", ...) == 0 then
      seed()
      return rs(yield(seed(20261005, 0)))
    end
    return rs(yield(seed(...)))
  end
  math.randomseed = wrap(rs)
end;
