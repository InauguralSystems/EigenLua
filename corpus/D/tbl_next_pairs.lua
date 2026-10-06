-- surface: tables next and pairs over insertion and deletion
-- Traversal order is unspecified, even for integer keys (manual, next), so
-- every traversal is collected and sorted before printing.
local function sorted(t)
  local rows = {}
  local k, v = next(t)
  while k ~= nil do
    rows[#rows + 1] = tostring(k) .. "=" .. tostring(v)
    k, v = next(t, k)
  end
  table.sort(rows)
  return table.concat(rows, " ")
end
local t = {}
t[1] = "a"
t[2] = "b"
t[3] = "c"
t[2] = nil
print("next", sorted(t))
t[2] = "B"
t[4] = "d"
t[1] = nil
local rows = {}
for i, val in pairs(t) do
  rows[#rows + 1] = tostring(i) .. "=" .. val
end
table.sort(rows)
print("pairs", table.concat(rows, " "))
local h = {b = 1, a = 2, c = 3}
h.b = nil
h.d = 4
print("hash", sorted(h))
-- clearing fields during traversal is allowed (manual, next)
local n = 0
for key in pairs(h) do
  h[key] = nil
  n = n + 1
end
print("cleared", n, next(h) == nil)
print("empty", next({}) == nil)
