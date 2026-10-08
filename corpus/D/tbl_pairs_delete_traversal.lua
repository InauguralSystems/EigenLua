-- surface: deleting existing fields during pairs traversal remains valid
print("iterator", (pairs({})) == next)
local t = {[1] = "array", [4] = "number", alpha = "hash", beta = "hash"}
local expected = 4
local seen = 0
for k in pairs(t) do
  t[k] = nil
  seen = seen + 1
end
print(seen == expected, next(t) == nil)
