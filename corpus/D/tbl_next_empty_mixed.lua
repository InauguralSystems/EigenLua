-- surface: next handles empty tables and visits array and hash storage
print("iterator", (pairs({})) == next)
print("empty", next({}) == nil)
local t = {[1] = "one", [2] = "two", name = "hash", [false] = "object"}
local kinds = {}
local count = 0
local k = next(t)
while k ~= nil do
  kinds[type(k)] = true
  count = count + 1
  k = next(t, k)
end
print("mixed", count, kinds.number == true, kinds.string == true, kinds.boolean == true)
