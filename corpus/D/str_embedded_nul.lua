-- surface: strings embedded NUL
local s = "a\0b\0"
print(#s)
print(string.byte(s, 1, #s))
print(load("return " .. string.format("%q", s))() == s)
print(string.find(s, "\0", 1, true))
