-- surface: load with a reader function (lbaselib.c generic_reader, ldo.c luaD_protectedparser): a reader error is returned as nil, msg after passing through the message handler in force; pieces are read on demand, so a syntax error stops the reads where llex.c's one-character lookahead stops
print(pcall(load, function() error("x") end))
local n = 0
local parts = {"x = ", "= 1", "print(1)", "print(2)", "print(3)"}
print(load(function() n = n + 1 return parts[n] end))
print(n)
n = 0
parts = {"local a ", "= 1 ", "return a", " + 1"}
local f = load(function() n = n + 1 return parts[n] end)
print(f(), n)
n = 0
parts = {"return 'ab", "\\q", "cd'", "x"}
print(load(function() n = n + 1 return parts[n] end))
print(n)
n = 0
local s = "return 1 + 2 + 3 + @ + 4 + 5"
print(load(function() n = n + 1 return s:sub(n, n) end))
print(n)
-- outside any pcall the reader error passes through lua.c's message handler; only its first line is printed
local function first(f, m) print(f, (string.gsub(m, "\n.*", ""))) end
first(load(function() return {} end))
n = 0
n = 0
first(load(function() n = n + 1 if n == 1 then return "return 1" end error({}) end))
print(n)
n = 0
s = "return [==[ab]=]cd]==]..'x'"
local g = load(function() n = n + 1 return s:sub(n, n) end)
print(g(), n)
-- more read-count cases
local function count(parts)
  local n = 0
  local f, m = load(function() n = n + 1 return parts[n] end)
  print(f ~= nil, m, n)
end
count({"x = 3x", "yz + 1", "print(1)"})
count({"x = '\\x4", "1' print(x) +", "+ 2", "3"})
count({"local t = {a", " = 1, b", "}", "x"})
count({"return 1 -", "- comment", "\n2"})
count({"x = [", "[long]", "] + ", "1"})
count({"x = [=", "x"})
-- the handler in force applies: lua.c's adds a traceback, pcall has none, xpcall's own runs
local _, m1 = load(function() error("y") end)
print((string.find(m1, "\nstack traceback:\n", 1, true)) ~= nil)
print(pcall(function() local _, m = load(function() error("y") end) return m end))
print(xpcall(function() local _, m = load(function() error("z") end) return m end, function(m) return "handled " .. m end))
