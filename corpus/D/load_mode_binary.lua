-- surface: load's mode looks at the first character (ldo.c checkmode): a chunk starting with the signature byte 27 is binary, so mode 't' refuses it, for strings and for readers
print(load("\27Lua", "b", "t"))
print(load("\27", "=bin", "t"))
print(load("x = 1", "c", "b"))
print(load("", "=empty", "b"))
local n = 0
print(load(function() n = n + 1 if n == 1 then return "\27Lua" end end, "bin", "t"))
print(n)
n = 0
print(load(function() n = n + 1 if n == 1 then return "return 1" end end, "txt", "b"))
print(n)
print(load("\27Lua", "b", "tx"))
