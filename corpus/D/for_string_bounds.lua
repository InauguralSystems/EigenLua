-- surface: numeric for: string control values convert to numbers and make a float loop (lvm.c forprep, luaV_tonumber_)
local function run(a, b, c)
  local out = {}
  if c then
    for i = a, b, c do out[#out + 1] = string.format("%d", i) end
  else
    for i = a, b do out[#out + 1] = string.format("%d", i) end
  end
  return #out .. ": " .. table.concat(out, " ")
end
print(run("10", "1", "-2"))
print(run(1, "3"))
print(run("0x10", 17))
print(run(" 2 ", 4, "1"))
print(pcall(run, "x", 2))
print(pcall(run, 1, {}))
print(pcall(run, 1, 2, "zero"))
print(pcall(run, 1, 2, "0"))
print(pcall(run, 1, 2, 0))
print(pcall(run, "1", nil, 1))
