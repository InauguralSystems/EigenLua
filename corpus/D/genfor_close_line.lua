-- surface: the generic for's closing value (its fourth value) is closed where lparser.c closes the loop's scope: debug.getinfo(2).currentline in its __close is the loop's 'end' line on normal exit and on break (one-line and multi-line headers), a forward goto's label line, the return's line, and -1 (pcall, a C function) when an error unwinds it
local function cl(tag)
  return setmetatable({}, {__close = function()
    local i = debug.getinfo(2, "l")
    print(tag, i and i.currentline)
  end})
end
local function iter(s, c) if c < 2 then return c + 1 end end
for i in iter, nil, 0, cl("normal") do
  local x = i
end
for i in iter, nil, 0, cl("break") do
  if i == 1 then
    break
  end
end
for i in iter, nil, 0, cl("goto") do
  if i == 1 then
    goto out
  end
end
::out::
print(pcall(function()
  for i in iter, nil, 0, cl("error") do
    error("x")
  end
end))
local function r()
  for i in iter, nil, 0, cl("return") do
    return i
  end
end
r()
for i in iter, nil, 0,
  cl("multi") do local y = i
end
do
  for i in iter, nil, 0, cl("nested") do
    for j in iter, nil, 0, cl("inner") do
      if j == 1 then goto done end
    end
  end
  ::done::
end
print(pcall(function()
  for i in iter, nil, 0, cl("error2") do
    local t = nil
    local z = t.x
  end
end))
