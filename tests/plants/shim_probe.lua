-- Plant shim-visible: what the debug library and error machinery report around
-- assert calls. tools/selftest.sh runs this file under the reference twice,
-- plain and as a tier S program (tools/grade.sh --shim), and requires
-- byte-identical stdout. Not covered here, and visible under the shim:
-- debug.getinfo(assert).nups and debug.getupvalue(assert, 1) (also for
-- os.exit and math.randomseed), and memory use.
local out = {}
local function put(...)
  local t = table.pack(...)
  for i = 1, t.n do t[i] = tostring(t[i]) end
  out[#out + 1] = table.concat(t, " ")
end
local function where(level)
  local i = debug.getinfo(level + 1, "Slnt")
  if not i then return "nil" end
  return string.format("%s:%s %s %s/%s tail=%s", i.short_src, i.currentline,
    i.what, i.namewhat, tostring(i.name), tostring(i.istailcall))
end
local function stack(from)
  local l = from + 1
  while debug.getinfo(l, "S") do put("  frame", l - from, where(l)) l = l + 1 end
end

put("top", where(1)) stack(1)
put("traceback-top", (debug.traceback("tb", 1):gsub("\n%s*", " | ")))

-- line hook events while asserts run, including failing ones
local function failing() assert(false, "inner") end
local lines = {}
debug.sethook(function(e, l)
  lines[#lines + 1] = debug.getinfo(2, "S").short_src .. ":" .. tostring(l)
end, "l")
assert(true)
local a, b, c = assert(1, 2, 3)
for i = 1, 3 do assert(i > 0, "loop") end
local ok1, m1 = pcall(assert, false)
local ok2, m2 = pcall(failing)
local ok3, m3 = pcall(function() assert(pcall(failing)) end)
debug.sethook()
put("line-events", #lines, table.concat(lines, " "))
put("returns", a, b, c, ok1, m1, ok2, m2, ok3, m3)

-- call and return hooks: the frames seen while assert is entered
local calls = {}
debug.sethook(function(e)
  local f = debug.getinfo(2, "f").func
  if f == assert then
    local s = e
    for l = 2, 6 do s = s .. " [" .. where(l) .. "]" end
    calls[#calls + 1] = s
  end
end, "cr")
assert(1)
pcall(assert, nil, "x")
debug.sethook()
put("call-events", #calls) for _, s in ipairs(calls) do put(" ", s) end

-- count hook: VM instructions executed by the calling thread
local ticks = 0
debug.sethook(function() ticks = ticks + 1 end, "", 1)
for i = 1, 5 do assert(i, i) end
debug.sethook()
put("count-hook", ticks)

-- error values and positions
local t = {}
put("e1", pcall(assert, false))
put("e2", pcall(assert, nil, "m"))
put("e3", select(2, pcall(assert, false, t)) == t)
put("e4", pcall(assert))
put("e5", pcall(function() assert(false) end))
put("e6", pcall(function() assert(nil, "pos") end))
put("e7", pcall(function() local x = assert(false, 42) end))
put("e8", pcall(assert, false, nil))
local function lvl2() error("two", 2) end
put("e9", pcall(function() lvl2() end))
put("e10", xpcall(failing, debug.traceback))
put("e11", xpcall(function() assert(false) end, function(m) return where(2) .. " " .. m end))
local function deep() return where(1) .. " < " .. where(2) .. " < " .. where(3) end
put("levels", deep())
put("type", type(assert), select("#", assert(true)), select("#", assert(true, nil, nil)))

print(table.concat(out, "\n"))
