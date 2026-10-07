-- surface: to-be-closed variables: a repeat-until condition runs before the body's <close> locals are closed (manual 3.3.4, 3.3.8)
local log = {}
local function mk(n)
  return setmetatable({}, {__close = function(_, e) log[#log + 1] = "close" .. n .. ":" .. tostring(e) end})
end
local i = 0
repeat
  i = i + 1
  local x <close> = mk(i)
until (function() log[#log + 1] = "cond" .. i; return i >= 2 end)()
print(table.concat(log, ","))

-- the condition sees the body's local, which is still open
log = {}
local j = 0
repeat
  j = j + 1
  local y <close> = mk(j)
  local open = true
until (function() log[#log + 1] = "sees" .. tostring(open); return true end)() and y
print(table.concat(log, ","))

-- an error in the condition closes the variable with that error
log = {}
print(pcall(function()
  repeat
    local z <close> = mk(9)
  until error("in cond", 0)
end))
print(table.concat(log, ","))
