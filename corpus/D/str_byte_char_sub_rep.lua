-- surface: strings byte char sub rep
local s = string.char(65, 0, 200)
print(string.byte(s, 1), string.byte(s, 2), string.byte(s, 3))
print(string.sub(s, 2, 3) == string.char(0, 200))
print(#string.rep("ab", 4))
print(string.rep("x", 0) == "")
print(string.sub("hello", -2))
print(string.char(97, 98, 99))
