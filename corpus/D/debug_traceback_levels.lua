-- surface: debug.traceback follows lauxlib.c luaL_traceback: LEVELS1/LEVELS2 with "...\t(skipping N levels)", global names for C and Lua functions, "function <src:line>" for an unnamed Lua function, no C level below a coroutine body
local function r(n)
  if n == 0 then return debug.traceback("m") end
  local ok, v = pcall(r, n - 1)
  return v
end
print(select(2, pcall(r, 3)))
print(select(2, pcall(r, 30)))
print(debug.traceback("x", 1))
print(debug.traceback())
local co = coroutine.create(function() print(debug.traceback("in co")) end)
coroutine.resume(co)
print(string.gsub("a", "a", function() return debug.traceback("g", 2) end))
