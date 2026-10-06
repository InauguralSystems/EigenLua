-- surface: closures loop-variable capture per iteration
local fs = {}
for i = 1, 4 do
  local v = i
  fs[i] = function() return v end
end
for i = 1, 4 do
  print(i, fs[i]())
end
