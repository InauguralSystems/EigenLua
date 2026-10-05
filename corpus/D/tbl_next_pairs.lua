-- surface: tables next and pairs over insertion and deletion
local t = {}
t[1] = "a"
t[2] = "b"
t[3] = "c"
t[2] = nil
local k, v = next(t)
while k ~= nil do
  print("next", k, v)
  k, v = next(t, k)
end
t[2] = "B"
t[4] = "d"
t[1] = nil
local rows = {}
for i, val in pairs(t) do
  rows[#rows + 1] = tostring(i) .. "=" .. val
end
table.sort(rows)
for i = 1, #rows do print("pairs", rows[i]) end
local h = {b = 1, a = 2, c = 3}
h.b = nil
h.d = 4
local hk = {}
for key, val in pairs(h) do
  hk[#hk + 1] = key .. "=" .. tostring(val)
end
table.sort(hk)
for i = 1, #hk do print("hash", hk[i]) end
