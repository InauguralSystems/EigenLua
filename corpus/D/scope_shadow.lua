-- surface: local shadowing
local function f(name)
  local name = name .. "!"
  return name
end
print(f("a"))
x = "global"
do
  local x = "local"
  print(x)
end
print(x)
