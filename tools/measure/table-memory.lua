-- EigenLua #31 table-memory workload.  Keep every allocation live until exit.
-- Usage: lua table-memory.lua MODE N
-- MODE: empty, array, strings, sparse, small4, or baseline.
-- EigenLua currently does not forward host argv to a compiled chunk, so the
-- environment fallback makes the identical source runnable in both arms.
local mode = assert(arg[1] or os.getenv("MEASURE_MODE"))
local n = assert(tonumber(arg[2] or os.getenv("MEASURE_N")))
local root = {}

if mode == "empty" then
  for i = 1, n do root[i] = {} end
elseif mode == "array" then
  for i = 1, n do root[i] = i end
elseif mode == "strings" then
  for i = 1, n do root["k" .. i] = i end
elseif mode == "sparse" then
  -- Stay outside the array part in both implementations.
  for i = 1, n do root[2 * i] = i end
elseif mode == "small4" then
  for i = 1, n do
    root[i] = { tag = i, first = i + 1, second = i + 2, value = i + 3 }
  end
elseif mode ~= "baseline" then
  error("unknown mode: " .. mode)
end

-- An observable use prevents a future optimizer from discarding root.
io.stderr:write("MEASURE-CHECK:", #root, "\n")
