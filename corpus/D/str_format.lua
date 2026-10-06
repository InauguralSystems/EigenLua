-- surface: strings string.format
print(string.format("%d %s %x %%", 255, "ok", 255))
-- %q text is only guaranteed to read back as the same string (manual,
-- string.format), so the program prints the round trip, not the escapes.
local function rt(s) return load("return " .. string.format("%q", s))() == s end
print(rt("a\"b"), rt("a\0b"), rt("\r\n\\"))
print(string.format("%05d", 42))
print(string.format("%.3f", 1.5))
