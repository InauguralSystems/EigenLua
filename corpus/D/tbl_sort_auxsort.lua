-- surface: table.sort is ltablib.c's auxsort quicksort (n < RANLIMIT, so no random pivot): lua_geti/lua_seti order, "invalid order function for sorting", "array too big", lua_compare operand order
print(pcall(table.sort, {1, 2, 3, 4}, function() return true end))
print(pcall(table.sort, setmetatable({}, {__len = function() return 1 << 31 end})))
print(pcall(table.sort, {3, 1, "a", 2}))
print(pcall(table.sort, {1, 2}, 3))
local function proxy(raw, log)
  return setmetatable({}, {
    __len = function() return #raw end,
    __index = function(_, k) log[#log + 1] = "r" .. k return raw[k] end,
    __newindex = function(_, k, v) log[#log + 1] = "w" .. k .. "=" .. tostring(v) raw[k] = v end})
end
for _, raw in ipairs({{3, 1, 2}, {2, 1}, {5, 4, 3, 2, 1}, {1, 3, 2, 5, 4, 6}}) do
  local log = {}
  table.sort(proxy(raw, log))
  print(table.concat(raw, ","), table.concat(log, " "))
end
local calls = {}
local t = {}
for i = 1, 40 do t[i] = (i * 37) % 41 end
table.sort(t, function(a, b) calls[#calls + 1] = a .. "<" .. b return a < b end)
print(table.concat(t, " "))
print(#calls, table.concat(calls, " ", 1, 12))
