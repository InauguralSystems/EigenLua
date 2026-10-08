-- surface: next cursor tombstones are compacted on later insertion
local t = {}
local visits = 0
for i = 1, 5000 do
  local k = "key-" .. i
  t[k] = i
  for seen, value in pairs(t) do
    visits = visits + 1
    assert(seen == k and value == i)
  end
  t[k] = nil
end

local empty = 0
for _ = 1, 5000 do
  if next(t) == nil then empty = empty + 1 end
end
print(visits, empty, next(t) == nil)
