-- surface: errors: a method call on a nil receiver names the receiver (EigenLua#5 a)
local function msg(e)
  -- drop "<path>.lua:" so the output does not depend on where the file lives
  for i = 1, #e - 4 do
    if e:sub(i, i + 4) == ".lua:" then return e:sub(i + 5) end
  end
  return e
end
local function try(f)
  local ok, e = pcall(f)
  print(ok, msg(e))
end
local s
try(function() s:foo() end)
try(function() local u; u:bar(1) end)
local t = {}
try(function() t.x:baz() end)
try(function() undefined_global:m() end)
try(function() t:missing() end)
try(function() ("x"):nosuch() end)
local n = 5
try(function() n:up() end)
