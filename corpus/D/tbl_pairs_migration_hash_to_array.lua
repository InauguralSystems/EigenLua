-- surface: hash keys absorbed by array growth are not visited twice
local t = {}
for _ in pairs(t) do end
t[2] = "b"
t[1] = "a"
local count, sum = 0, 0
for k in pairs(t) do
  count = count + 1
  sum = sum + k
  if count > 20 then print("RUNAWAY") return end
end
print(count, sum, #t)
