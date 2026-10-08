-- surface: next uses the current array/hash boundary after array shrinkage
local t = {1, 2, 3, 4, 5}
for _ in pairs(t) do end
table.remove(t)
table.remove(t)
table.remove(t)
t[5] = "z"
local count, sum = 0, 0
for k in pairs(t) do
  count = count + 1
  sum = sum + k
  if count > 30 then print("RUNAWAY") return end
end
print(count, sum)
