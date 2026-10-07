-- surface: to-be-closed variables: the fourth value of a generic for is closed on normal exit, break, return and error (manual 3.3.5)
local log = {}
local function mk(n)
  return setmetatable({}, {__close = function(_, e) log[#log + 1] = "close" .. n .. ":" .. tostring(e) end})
end
local function it(_, c) if c < 3 then return c + 1 end end

for i in it, nil, 0, mk(1) do log[#log + 1] = "i" .. i end
print(table.concat(log, ","))

log = {}
for i in it, nil, 0, mk(2) do
  log[#log + 1] = "i" .. i
  if i == 2 then break end
end
print(table.concat(log, ","))

log = {}
local function f()
  for i in it, nil, 0, mk(3) do
    if i == 1 then return "ret" end
  end
end
local r = f()
log[#log + 1] = r
print(table.concat(log, ","))

log = {}
print(pcall(function()
  for i in it, nil, 0, mk(4) do error("boom", 0) end
end))
print(table.concat(log, ","))

-- the value comes from the explist, so a function returning four values works
log = {}
local function four() return it, nil, 0, mk(5) end
for i in four() do log[#log + 1] = "i" .. i end
print(table.concat(log, ","))

-- nil and false are not closed; other values without __close are an error
for i in it, nil, 2, nil do print("nil ok", i) end
for i in it, nil, 2, false do print("false ok", i) end
print(pcall(function() for i in it, nil, 0, 42 do end end))
