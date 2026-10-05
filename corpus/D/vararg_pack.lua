-- surface: varargs select table.pack and table.unpack
local function f(...)
  print(select("#", ...))
  local p = table.pack(...)
  print(p.n)
  for i = 1, p.n do
    if p[i] == nil then print(i, "nil") else print(i, p[i]) end
  end
  return table.unpack(p, 1, p.n)
end
local a, b, c = f("x", nil, "y")
print(a, tostring(b), c)
print(select(2, "p", "q", "r"))
