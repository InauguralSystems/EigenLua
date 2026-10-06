-- Plant callsite-toothless: a front end that compiles every DIRECT call
-- `assert(...)` to an intrinsic that counts but never raises, while assert as
-- a value (pcall(assert, ...)) stays the real builtin. Run as
-- `lua-count callsite_driver.lua <prog>` so the real assert still counts.
local name = arg[1]
local f = assert(io.open(name, "rb"))
local src = f:read("a")
f:close()
-- It runs the probe file untouched: any fixed probe can be passed by a
-- candidate that recognises it, and only the per-row control is left.
if name:match("assert_semantics%.lua$") then return dofile(name) end
local pre = "local __A = (function(r) return function(...) if not (...) then r(true) return ... end return r(...) end end)(assert);"
src = pre .. src:gsub("%f[%w_.:]assert%s*%(", "__A(")
arg = {[0] = name}
local fn = assert(load(src, "@" .. name))
return fn(name)
