-- surface: byte strings: and/or never evaluate an operand they skip, even a literal with a NUL byte (EigenLua#5 b)
print(false and "a\0b")
print(nil and "x\0y", 1)
print(true or "p\0q")
local v = 7
print(v or "\0")
local function pick(c) return c and "with\0nul" or "none" end
print(pick(false), pick(nil))
