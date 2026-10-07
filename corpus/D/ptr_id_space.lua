-- surface: tostring and string.format('%p') of reference values draw on one address space: tables, Lua and C functions, threads, userdata and strings never share an address while alive, and tostring's address is the one '%p' prints
local vals = {print, string.format, io.stdout, coroutine.running()}
for i = 1, 25 do
  vals[#vals + 1] = {}
  vals[#vals + 1] = function() return i end
  vals[#vals + 1] = coroutine.create(function() end)
  vals[#vals + 1] = ("s"):rep(40 + i)
  vals[#vals + 1] = setmetatable({}, {__index = vals})
end
local seen, dup = {}, 0
for _, v in ipairs(vals) do
  local p = string.format("%p", v)
  if seen[p] then dup = dup + 1 end
  seen[p] = true
end
print(#vals, "duplicates", dup)
local same = 0
for _, v in ipairs(vals) do
  if type(v) ~= "string" and type(v) ~= "userdata" then
    local s = tostring(v)
    if s:sub(#s - #string.format("%p", v) + 1) == string.format("%p", v) then same = same + 1 end
  end
end
print("tostring = %p", same)
print(string.format("%p", 1), string.format("%p", true), string.format("%p", nil))
