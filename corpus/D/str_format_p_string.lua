-- surface: string.format('%p', s) of a string names that string (lua_topointer): the same string, and a short string equal to it, format alike every time
-- %p of a string names one string: the same string formats alike every time
local s = string.rep("a", 100)
print(string.format("%p", s) == string.format("%p", s))
local r = string.gsub(s, "b", "c")
print(string.format("%p", s) == string.format("%p", r))
local t = "short"
print(string.format("%p", t) == string.format("%p", "sho" .. "rt"))
print(string.format("%p", s) ~= string.format("%p", t))
