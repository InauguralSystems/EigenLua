-- EigenLua #31 tight table-access microbenchmark.
-- Usage: lua table-access.lua [iterations].  The fixed working set keeps the
-- measurement focused on lookup/update cost rather than allocation.
local n = tonumber(arg[1] or os.getenv("MEASURE_N")) or 5000000
local t = {}
for i = 1, 256 do
  t[i] = i
  t["k" .. i] = i
end
local sum = 0
for i = 1, n do
  local k = (i % 256) + 1
  sum = sum + t[k] + t["k" .. k]
  t[k] = t[k] + 1
end
io.stderr:write("ACCESS-CHECK:", sum, ":", t[1], "\n")
