-- surface: strings embedded NUL
local s = "a\0b\0"
print(#s)
print(string.byte(s, 1, #s))
print(string.format("%q", s))
print(string.find(s, "\0", 1, true))
