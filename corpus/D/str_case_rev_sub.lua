-- surface: strings upper lower reverse rep and sub with negative indices
local s = "Hello, World 42"
print(string.upper(s), string.lower(s))
print(("abc"):upper(), ("XyZ"):lower())
print(string.reverse(s), ("ab"):reverse(), ("") :reverse() == "")
print(string.rep("ab", 3), string.rep("ab", 3, "-"), string.rep("x", 1, "-"))
print(string.rep("x", 0) == "", string.rep("x", -1) == "")
print(s:sub(1, 5), s:sub(-2), s:sub(-5, -3), s:sub(8))
print(s:sub(0), s:sub(-100, 3), s:sub(5, 2) == "", s:sub(14, 100))
print(#s:sub(2, -2), s:sub(-1, -1), s:sub(100) == "")
-- strings over 64 bytes
local long = string.rep("The Quick Brown Fox 0123456789 ", 4) .. "end"
print(#long, string.upper(long))
print(string.lower(long))
print(string.reverse(long))
print(#string.rep(long, 3, "|"), string.rep("ab", 40, ","):sub(-9))
print(string.upper(long):sub(70), string.lower(long):sub(-20), long:reverse():sub(1, 70))
