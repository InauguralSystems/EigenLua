-- surface: strings embedded NUL
local s = "a\0b\0"
print(#s)
print(string.byte(s, 1, #s))
print(load("return " .. string.format("%q", s))() == s)
print(string.find(s, "\0", 1, true))
print(string.upper("a\0b") == "A\0B", #string.lower("X\0Y\0Z"), string.byte(string.upper("q\0r"), 1, -1))
