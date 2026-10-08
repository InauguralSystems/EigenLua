-- surface: deterministic mutation fuzz for array/hash traversal migrations
local seed = 3430008
local function rand(n)
  -- Products remain below 2^53, so Lua integers and EigenLua's exact-double
  -- integer subset generate identical streams.
  seed = (seed * 48271) % 2147483647
  return seed % n
end

local tabs = {{}, {}, {}}
local function traverse(t, step)
  -- Give # a unique border; mutations between traversals still exercise
  -- sparse integer storage, but the printed observation is specified.
  local prefix = rand(9)
  for k = 1, 100 do t[k] = nil end
  for k = 1, prefix do t[k] = step + k end
  local length = #t

  local expected = 0
  for k = 1, 100 do if t[k] ~= nil then expected = expected + 1 end end
  for k = 1, 8 do if t["s" .. k] ~= nil then expected = expected + 1 end end

  local count, sum, strings = 0, 0, {}
  for k in pairs(t) do
    count = count + 1
    if count > math.max(1, expected) * 10 then print("RUNAWAY", step) return false end
    if type(k) == "number" then
      sum = sum + k
    else
      strings[#strings + 1] = k
    end
    -- Deleting the current key and reassigning an existing key are both
    -- defined during traversal.  Depend on the key, not traversal order.
    local tag = type(k) == "number" and k or string.byte(k, 2)
    if (tag + step) % 11 == 0 then t[k] = nil else t[k] = step end
  end
  table.sort(strings)
  print(count, sum, table.concat(strings, ","), length)
  return count == expected
end

-- Force the critic's hash-to-array migration before the generated stream;
-- round 3 prints RUNAWAY here, while the fixed iterator visits two keys.
for _ in pairs(tabs[1]) do end
tabs[1][2], tabs[1][1] = 2, 1
if not traverse(tabs[1], 0) then return end

for step = 1, 2000 do
  local t = tabs[rand(#tabs) + 1]
  local op = rand(8)
  if op == 0 then
    local k = rand(20) + 1; t[k] = step
  elseif op == 1 then
    local k = rand(8) + 1; t["s" .. k] = step
  elseif op == 2 then
    local k = rand(20) + 1; t[k] = nil
  elseif op == 3 then
    local k = rand(8) + 1; t["s" .. k] = nil
  elseif op == 4 then
    table.insert(t, step)
  elseif op == 5 then
    if #t > 0 then table.remove(t) end
  elseif op == 6 then
    table.insert(t, math.floor(#t / 2) + 1, step)
  else
    if #t > 0 then table.remove(t, math.floor((#t + 1) / 2)) end
  end
  if step % 17 == 0 and not traverse(t, step) then return end
end
