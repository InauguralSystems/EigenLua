-- surface: pairs honours __pairs and preserves exactly its first three results
print("default iterator", (pairs({})) == next)
local calls = 0
local marker = {}
local function iterator(state, control)
  if control == nil then return "key", state.value end
end
local t
t = setmetatable({}, {__pairs = function(self)
  calls = calls + 1
  print("self", self == t)
  return iterator, {value = 17}, nil, "discarded"
end})
local iter, state, initial, fourth = pairs(t)
print("results", iter == iterator, state.value, initial == nil, fourth == nil, calls)
for k, v in pairs(t) do print("loop", k, v) end
print("calls", calls)
