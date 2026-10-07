-- surface: an error raised by the host VM inside Lua code (non-finite arithmetic, out-of-domain math) is a Lua error located at the Lua line it came from; the value itself is the no-nonfinite gap, so each case prints true when it runs (as in Lua) or when its error carries that line
local x, z = -8, 0
local function located(line, f)
  local ok, e = pcall(f)
  return ok or (type(e) == "string" and e:find("^err_eigs_located%.lua:" .. line .. ": ") ~= nil)
end
print(located(9, function()
  local third = 1 / 3
  return x ^ third
end))
print(located(13, function()
  local y = 1
  return z / z + y
end))
print(located(17, function()
  local y = 0
  return math.log(y)
end))
print(located(21, function()
  local y = -1
  return math.sqrt(y) // 1
end))
