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
