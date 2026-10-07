-- surface: builtin return values, each through pcall as type and value or err: tonumber with and without a base, the math functions over a fixed argument set, next, select, type, rawequal, rawlen, rawget, rawset, getmetatable, setmetatable, tostring, assert, pcall, error, ipairs, collectgarbage
-- each call through pcall: the type and value of every result, or err
-- (numbers as %.17g, so an integer and an equal float print alike; NaN as nan)
local function show(...)
  local out = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    local t = type(v)
    if t == "number" then
      if v ~= v then out[i] = "number:nan" else out[i] = "number:" .. string.format("%.17g", v) end
    elseif t == "string" then out[i] = "string:" .. string.format("%q", v)
    elseif t == "nil" or t == "boolean" then out[i] = t .. ":" .. tostring(v)
    else out[i] = t end
  end
  return #out .. " " .. table.concat(out, " ")
end
local function try(name, f, ...)
  local r = table.pack(pcall(f, ...))
  if r[1] then print(name, show(table.unpack(r, 2, r.n))) else print(name, "err") end
end
-- tonumber
for _, a in ipairs({"10", "0x10", " 12 ", "1e2", ".5", "5.", "abc", "", " ", "0x", "1e", "- 1", "-0x10", "1 2", "0x1p4", "inf", "nan"}) do
  try("tonumber " .. string.format("%q", a), tonumber, a)
end
try("tonumber 7", tonumber, 7)
try("tonumber table", tonumber, {})
try("tonumber nil", tonumber, nil)
try("tonumber none", tonumber)
for _, c in ipairs({{"ff", 16}, {"FF", 16}, {"z", 36}, {"Z", 36}, {"8", 8}, {"777", 8}, {"101", 2}, {"-101", 2}, {"  11  ", 3}, {"1.5", 10}, {"", 10}, {"12", 37}, {"12", 1}}) do
  try("tonumber " .. c[1] .. " base " .. c[2], tonumber, c[1], c[2])
end
try("tonumber number base", tonumber, 10, 16)
-- math
local M = {
  {"abs", -3}, {"abs", 2.5}, {"abs", 0},
  {"ceil", 2.1}, {"ceil", -2.1}, {"ceil", 3}, {"floor", -2.5}, {"floor", 3}, {"floor", 2.9},
  {"sqrt", 16}, {"sqrt", 2}, {"exp", 0}, {"exp", 1}, {"log", 1}, {"log", 8, 2}, {"log", 100, 10}, {"log", 27, 3},
  {"sin", 0}, {"cos", 0}, {"tan", 0}, {"asin", 1}, {"acos", 1}, {"atan", 1}, {"atan", 1, 2}, {"atan", -1, -1}, {"atan", 0, -1},
  {"deg", math.pi}, {"rad", 180},
  {"fmod", 7, 3}, {"fmod", -7, 3}, {"fmod", 7, -3}, {"fmod", 7.5, 2}, {"fmod", 1, 0},
  {"modf", 3.7}, {"modf", -3.7}, {"modf", 5},
  {"max", 1, 5, 3}, {"max", -1.5, -2}, {"max", 4}, {"max"}, {"min", 4, 2, 8}, {"min", 2.5, 1}, {"min", "b", "a"},
  {"tointeger", 3}, {"tointeger", 3.5}, {"tointeger", "8"}, {"tointeger", "x"}, {"tointeger", 2^31},
  {"ult", 1, 2}, {"ult", -1, 2}, {"ult", 2, -1}, {"ult", 1.5, 2},
  {"type", 1}, {"type", 1.5}, {"type", "1"}, {"type", nil}, {"type"},
  {"abs", "x"}, {"floor", "2.5"}, {"sqrt", {}},
}
for _, c in ipairs(M) do
  local args = {table.unpack(c, 2)}
  local label = "math." .. c[1]
  for i = 2, #c do
    local a = c[i]
    if type(a) == "number" then a = string.format("%.17g", a) elseif type(a) == "table" then a = "table" end
    label = label .. " " .. tostring(a)
  end
  try(label, math[c[1]], table.unpack(c, 2, #c))
end
print("pi", string.format("%.17g", math.pi))
print("mininteger", string.format("%.17g", math.mininteger), math.type(math.mininteger))
-- next, select, type, raw*
try("next empty", next, {})
try("next seq", next, {10})
try("next after last", next, {10}, 1)
try("next nonkey", next, {10}, 2)
try("next nontable", next, 5)
try("select #", select, "#")
try("select # nils", select, "#", 1, nil, nil)
try("select 2", select, 2, "a", "b", "c")
try("select -1", select, -1, "a", "b")
try("select -3", select, -3, "a", "b")
try("select 0", select, 0)
try("select 5", select, 5, "a")
try("select x", select, "x")
for _, v in ipairs({1, 1.5, "s", true, false, {}, print, coroutine.create(print)}) do try("type", type, v) end
try("type nil", type, nil)
try("type none", type)
local t1, t2 = {}, {}
try("rawequal same", rawequal, t1, t1)
try("rawequal diff", rawequal, t1, t2)
try("rawequal 1 1.0", rawequal, 1, 1.0)
try("rawequal str", rawequal, "a", "a")
try("rawequal 1 '1'", rawequal, 1, "1")
try("rawequal one", rawequal, 1)
try("rawlen seq", rawlen, {1, 2, 3})
try("rawlen str", rawlen, "abcd")
try("rawlen num", rawlen, 5)
try("rawlen meta", rawlen, setmetatable({1}, {__len = function() return 9 end}))
try("rawget", rawget, setmetatable({}, {__index = function() return 1 end}), "x")
try("rawget nontable", rawget, "x", 1)
try("rawset", function() local t = setmetatable({}, {__newindex = error}) rawset(t, "k", 2) return t.k end)
try("rawset nil key", rawset, {}, nil, 1)
try("getmetatable str", function() return getmetatable("").__index == string end)
try("getmetatable protected", getmetatable, setmetatable({}, {__metatable = "locked"}))
try("setmetatable protected", setmetatable, setmetatable({}, {__metatable = 1}), {})
try("tostring nil", tostring, nil)
try("tostring true", tostring, true)
try("tostring num", tostring, -0x10)
try("tostring meta", tostring, setmetatable({}, {__tostring = function() return "T" end}))
try("tostring none", tostring)
try("assert vals", assert, 1, 2, 3)
try("assert false", assert, false)
try("pcall vals", pcall, function(...) return ... end, 1, nil, 3)
try("error table", function() local ok, e = pcall(error, {code = 1}) return ok, type(e), e.code end)
try("error level 0", function() local ok, e = pcall(error, "m", 0) return e end)
try("ipairs", function() local s = 0 for i, v in ipairs({5, 6, nil, 7}) do s = s + i * v end return s end)
try("pairs seq", function() local s = 0 for k, v in pairs({5, 6, 7}) do s = s + k * v end return s end)
try("collectgarbage count type", function() return type(collectgarbage("count")) end)
try("collectgarbage isrunning", collectgarbage, "isrunning")
try("collectgarbage bad", collectgarbage, "nope")
