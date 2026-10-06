-- surface: tables integer and float keys are the same key
local t = {}
t[1] = "one"
t[1.0] = "one-float"
print(t[1])
print(t[1.0])
print(t[1] == t[1.0])
local keys = 0
for k, v in pairs(t) do
  keys = keys + 1
  print(math.type(k), k, v)
end
print("keys", keys)
