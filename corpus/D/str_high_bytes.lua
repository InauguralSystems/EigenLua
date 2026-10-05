-- surface: strings bytes at or above 0x80
local s = string.char(128, 255, 196)
print(#s)
print(string.byte(s, 1), string.byte(s, 2), string.byte(s, 3))
print(string.format("%q", s))
print(s == "\128\255\196")
