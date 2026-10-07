-- surface: positions and debug info of code compiled by load, whose call sites live with the chunk: error messages carry the chunk's name and line, a function from an early chunk still reports its own chunk after 500 later loads, getinfo gives each loaded function's source, short_src and lines, tracebacks name loaded chunks, and a chunk with more than 1024 sites compiles and runs
local early = load("local t = nil\nreturn function(k)\n  return t[k]\nend", "=early")()
local fs = {}
for i = 1, 500 do
  fs[i] = load("local a = ...\nreturn function()\n  return a.x + " .. i .. "\nend", "chunk" .. i)(i == 250 and {x = 1} or nil)
end
print(pcall(early, "k"))
print(pcall(fs[1]))
print(fs[250]())
print(pcall(fs[500]))
local i = debug.getinfo(fs[77], "S")
print(i.source, i.short_src, i.linedefined, i.lastlinedefined, i.what)
i = debug.getinfo(early, "S")
print(i.source, i.short_src, i.linedefined, i.lastlinedefined, i.what)
local m = load("return debug.getinfo(1, 'Sl')", "@virtual.lua")()
print(m.source, m.short_src, m.currentline, m.what)
print(xpcall(load("\n\nerror('deep')", "=handler"), function(e)
  local d = debug.getinfo(3, "Sl")
  return e .. " | " .. d.short_src .. ":" .. d.currentline
end))
local tb = load("return function() return debug.traceback('tb', 1) end", "=tbchunk")()()
print((tb:gsub("\n[^\n]*%[C%][^\n]*", "")))
local parts = {"local x = 0"}
for k = 1, 1200 do parts[#parts + 1] = "x = x + #'" .. k .. "'" end
parts[#parts + 1] = "return x, (nil)[x]"
local big = load(table.concat(parts, "\n"), "=big")
print(pcall(big))
print(select(2, load("x = = 1", "=bad")))
