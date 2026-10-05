-- surface: local block scope
local x = "outer"
do
  local x = "inner"
  print(x)
end
print(x)
do
  local y = 7
  print(y)
end
print(y)
