-- surface: lazy hash order and direct array traversal share a next cursor
local t = {"one", "two", "three", "four", alpha = "A", beta = "B"}
local k, v = next(t)
assert(k == 1 and v == "one")

-- Delete one future array entry and one future hash entry after traversal starts.
t[2] = nil
t.alpha = nil

local seen = {}
local count = 1
seen[k] = true
repeat
  k, v = next(t, k)
  if k ~= nil then
    assert(not seen[k])
    assert(k ~= 2 and k ~= "alpha")
    seen[k] = true
    count = count + 1
    if k == "beta" then
      t[k] = nil -- advancing from a deleted current hash key remains valid
    end
  end
until k == nil

print(count == 4, seen[1] == true, seen[3] == true, seen[4] == true,
      seen.beta == true, next(t, 4) == nil)
