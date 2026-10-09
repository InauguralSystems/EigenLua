-- surface: exact table discrimination across rawequal, rawget, rawlen, type, and tostring
-- Compact table records and every other exposed value shape must remain distinct.
local file = io.stdout
local thread = coroutine.create(function() end)
local tab = {}
local values = {
  {"nil", nil}, {"boolean", true}, {"number", 1.5}, {"string", "x"},
  {"function", function() end}, {"thread", thread}, {"userdata", file},
  {"table", tab},
}
local function outcome(f, ...)
  local ok, v = pcall(f, ...)
  if not ok then return "error" end
  if type(v) == "string" then return "string" end
  return type(v) .. ":" .. tostring(v)
end
for _, item in ipairs(values) do
  local name, value = item[1], item[2]
  print(name, type(value),
    outcome(rawequal, value, tab), outcome(rawequal, tab, value),
    outcome(rawget, value, tab), outcome(rawget, tab, value),
    outcome(rawlen, value), outcome(rawlen, tab),
    outcome(type, value), outcome(type, tab),
    outcome(tostring, value), outcome(tostring, tab))
end
