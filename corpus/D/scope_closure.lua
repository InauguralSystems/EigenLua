-- surface: closures capturing upvalues
local function counter()
  local n = 0
  return function(d)
    n = n + d
    return n
  end
end
local a = counter()
local b = counter()
print(a(1))
print(a(2))
print(b(10))
print(a(0))
