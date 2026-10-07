-- surface: debug: getinfo of a function value names a C function's frame [C] and a Lua function's chunk and lines (ldebug.c funcinfo)
local function test(s)
  local x = 1
  return x
end
local a = debug.getinfo(print)
print(a.what, a.short_src, a.currentline, a.linedefined, a.lastlinedefined)
local b = debug.getinfo(test)
print(b.what, b.short_src, b.currentline, b.linedefined, b.lastlinedefined)
local f = load("return 1", "=mychunk")
local c = debug.getinfo(f)
print(c.what, c.short_src, c.currentline, c.linedefined, c.lastlinedefined)
local g = load("\n\nreturn function()\nend", "@other.lua")()
local d = debug.getinfo(g)
print(d.what, d.short_src, d.linedefined, d.lastlinedefined)
print(debug.getinfo(string.gmatch("a", "a")).what, debug.getinfo(coroutine.wrap(print)).short_src)
print(debug.getinfo(math.max).what, debug.getinfo(function() end).what)
