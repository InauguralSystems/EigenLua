-- surface: builtins the other rows do not reach: _VERSION, string.packsize over formats and its errors, os.difftime, debug.getmetatable/setmetatable on a table and a string, warn's return and argument errors, loadfile and dofile on this very file (guarded so the reload stops), os.getenv of an unset variable, os.setlocale queries and the C locale, package.config
print(_VERSION)
for _, f in ipairs({"i4", "<i8", "d", "bhi", "!4 i3 d", "c10", "j n", "s4"}) do
  print(f, pcall(string.packsize, f))
end
print(os.difftime(10, 4) == 6, (pcall(os.difftime, 5)), pcall(os.difftime))
local t = setmetatable({}, {__index = {a = 1}})
print(debug.getmetatable(t).__index.a, debug.getmetatable("x").__index == string, debug.getmetatable(1))
print(debug.setmetatable(t, nil) == t, getmetatable(t))
print(warn("@off"), pcall(warn), pcall(warn, "a", {}))
if RELOADED then return "reloaded" end
RELOADED = true
local f = loadfile("builtin_values_more.lua")
print(type(f))
print(dofile("builtin_values_more.lua"))
print(os.getenv("EIGENLUA_SURELY_UNSET_VARIABLE"))
print(os.setlocale(), os.setlocale("C"), os.setlocale(nil, "numeric"), pcall(os.setlocale, "C", "bogus"))
print(package.config)
