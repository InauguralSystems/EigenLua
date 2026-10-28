-- surface: half-dense integer keys with an offset and descending insertion
local function exercise(t, first, last)
  assert(#t == 0)
  local count, sum = 0, 0
  for k, v in pairs(t) do
    assert(k >= first and k <= last and k % 2 == 1)
    count, sum = count + 1, sum + v
  end
  assert(count == 8 and sum == 36)

  local k = next(t)
  assert(k ~= nil)
  local old = t[k]
  t[k] = nil
  assert(t[k] == nil)
  t[k] = old
  assert(t[k] == old)
  assert(next(t) ~= nil)
end

local offset = {}
for i = 1, 8 do offset[1001 + 2 * i] = i end
exercise(offset, 1003, 1017)

local descending = {}
for i = 8, 1, -1 do descending[2000001 + 2 * i] = i end
exercise(descending, 2000003, 2000017)

-- Exercise both sides of the compact/hash admission boundary: the isolated
-- key stays hashed, while the subsequent half-dense run is compact.
local boundary = {}
for i = 1, 8 do boundary[3001 + 2 * i] = i end
boundary[9000001] = 9
assert(boundary[9000001] == 9 and boundary[3003] == 1 and boundary[3017] == 8)
boundary[9000001] = nil
boundary[9000001] = 10
assert(boundary[9000001] == 10)
print("sparse-shapes-ok")
