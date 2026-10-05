-- surface: error levels
local function inner()
  error("from-inner", 1)
end
local function mid()
  inner()
end
local ok, err = pcall(mid)
print(ok)
print(string.match(err, ":(%d+):"))
print(string.match(err, "from%-inner$") ~= nil)
local function inner2()
  error("from-caller", 2)
end
local function mid2()
  inner2()
end
ok, err = pcall(mid2)
print(ok)
print(string.match(err, ":(%d+):") ~= nil)
print(string.match(err, "from%-caller$") ~= nil)
