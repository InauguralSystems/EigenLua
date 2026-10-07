-- surface: debug.getinfo: source is the chunk's own name (the chunk text, '=name' or '@file') for loaded chunks; inside __close on the normal path, getinfo(2).currentline is the line where the variable closes (lparser.c lastline: a block's last token, a function's end, a return, a loop's end for break, a forward goto's label, a backward goto)
local function src(f) return debug.getinfo(f, "S").source end
print(src(1))
print(src(load("return 1")))
print(src(load("return 1", "=named")))
print(src(load("return 1", "@file.lua")))
print(src(load("local x = 1\nreturn function() return x end")()))
local n = 0
print(src(load(function() n = n + 1 if n == 1 then return "return 2" end end)))
print(src(load(function() n = n + 1 if n == 3 then return "return 3" end end, "=reader")))
print(load("return debug.getinfo(1, 'S').source", "chunk text")())
print(load("return debug.getinfo(1, 'S').short_src", "chunk text")())
print(src(print))
-- __close on the normal path: getinfo(2).currentline is where the variable closes
local function cl(tag)
  return setmetatable({}, {__close = function()
    local i = debug.getinfo(2, "l")
    print(tag, i.currentline)
  end})
end
do
  local a <close> = cl("do-end")
  local z = 1
end
local function f()
  local b <close> = cl("return")
  local z = 2
  return z
end
f()
local function g()
  local c <close> = cl("fall off")
  local z = 3
end
g()
for i = 1, 2 do
  local d <close> = cl("loop " .. i)
  if i == 2 then
    break
  end
end
do
  local e <close> = cl("goto")
  goto out
end
::out::
local function h()
  local q <close> = cl("return call")
  return print("x")
end
h()
repeat
  local r <close> = cl("repeat")
until true
while true do
  local w <close> = cl("while")
  break
end
local function m()
  local k <close> = cl("multi")
  local k2 <close> = cl("multi2")
  return
end
m()
i = 0
::top::
do
  i = i + 1
  local a <close> = cl("back" .. i)
  if i < 2 then
    goto top
  end
end
if i then
  local b <close> = cl("then")
  i = i + 1
elseif i then
  print()
else
  local c <close> = cl("else")
end
for k, v in pairs({1}) do
  local d <close> = cl("genfor")
  while true do
    local e <close> = cl("inner while")
    break
  end
end
local w <close> = cl("main")
local x = 1
