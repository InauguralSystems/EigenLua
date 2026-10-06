-- surface: assert raises, passes through and returns (also the tier S assert-trust probe)
-- tools/grade.sh runs this file on the candidate before any tier S row and
-- requires stdout and rc byte-identical to the reference, or every S row
-- fails as assert-untrusted. It checks assert only through pcall and prints
-- what came back, so a candidate assert that never raises changes the output.
local function show(label, ...)
  local t = table.pack(...)
  local o = {}
  for i = 1, t.n do
    local v = t[i]
    o[i] = type(v) == "table" and "<table>" or type(v) .. ":" .. tostring(v)
  end
  print(label, t.n, table.concat(o, " "))
end
-- raises on false and nil
show("false", pcall(assert, false))
show("nil", pcall(assert, nil))
show("false+msg", pcall(assert, false, "msg"))
show("nil+msg", pcall(assert, nil, "other"))
show("false+num", pcall(assert, false, 42))
local e = {}
local ok, v = pcall(assert, false, e)
print("false+table", ok, rawequal(v, e))
ok, v = pcall(assert, nil, nil)
print("nil+nil", ok, v == nil)
print("noarg", (pcall(assert)))
-- does not raise on other values, and returns all its arguments
show("zero", pcall(assert, 0))
show("empty", pcall(assert, ""))
show("true", pcall(assert, true, "unused"))
ok, v = pcall(assert, e)
print("table", ok, rawequal(v, e))
print("count", select("#", assert(1, 2, 3)), assert(1, 2, 3))
show("trailing", pcall(assert, 1, nil, nil))
-- DIRECT call sites (a front end may compile `assert(...)` differently from
-- assert used as a value); positions are printed only as "ends with".
local function direct(label, fn)
  local ok, e = pcall(fn)
  print(label, ok, type(e), type(e) == "string" and (e:match("assertion failed!$") or e:match("m$")) or "-")
end
local function none() end
local t = {}
direct("d-false", function() assert(false) end)
direct("d-nil+m", function() assert(nil, "m") end)
direct("d-noresult", function() assert(none()) end)
direct("d-compare", function() assert(0 == 1) end)
direct("d-missing", function() assert(t.missing) end)
direct("d-loop", function() for i = 1, 3 do assert(i < 3) end end)
direct("d-nested", function() local function inner() return assert(false, "m") end inner() end)
direct("d-true", function() assert(1 == 1, "never") end)
