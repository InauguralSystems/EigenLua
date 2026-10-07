-- surface: to-be-closed variables in blocks with labels: closed in the reference's order on a goto to the block's end, a backward goto that leaves their scope, a goto out of an inner loop, break, return, an error, and after a repeat-until condition
local function closer(name)
  return setmetatable({}, {__close = function(_, e) print("close", name, e) end})
end
-- goto past the rest of the block to a label at its end
do
  local x <close> = closer("x")
  print("in")
  goto skip
  print("not reached")
  ::skip::
end
-- a backward goto leaves the scope: closed each round
do
  local i = 0
  ::top::
  i = i + 1
  local y <close> = closer("y" .. i)
  if i < 3 then goto top end
  print("after loop", i)
end
-- labels inside the region, and a goto out of an inner loop
do
  local z <close> = closer("z")
  local n = 0
  ::again::
  n = n + 1
  for j = 1, 3 do
    if j == 2 and n < 2 then goto again end
  end
  local w <close> = closer("w")
  print("n", n)
end
-- break out of a loop through a block with labels
for k = 1, 3 do
  local a <close> = closer("a" .. k)
  ::l1::
  if k == 2 then break end
  local b <close> = closer("b" .. k)
  ::l2::
end
-- return from inside, and an error
local function f()
  do
    local r <close> = closer("r")
    ::x::
    do return "ret" end
  end
end
print(f())
print(pcall(function()
  local e <close> = closer("e")
  goto go
  ::go::
  error("boom")
end))
-- repeat-until: the condition sees the local, then it closes
local c = 0
repeat
  local u <close> = closer("u" .. c)
  c = c + 1
  ::cont::
until c >= 2
-- goto to the end label leaves without evaluating the rest
do
  goto fin
  local v <close> = closer("never")
  ::fin::
end
print("done")
