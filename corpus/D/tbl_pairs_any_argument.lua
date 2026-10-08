-- surface: pairs accepts every present value and leaves type checking to next
local function result(v)
  local ok, iter, state, control = pcall(pairs, v)
  print(ok, iter == next, state == v, control == nil)
end

result(nil)
result("s")

local ok, err = pcall(pairs)
print(ok, type(err) == "string" and err:match("bad argument #1 to 'pairs' %(value expected%)$") ~= nil)

ok, err = pcall(function()
  for _ in pairs(nil) do end
end)
print(ok, type(err) == "string" and err:match("bad argument #1 to 'for iterator' %(table expected, got nil%)$") ~= nil)
