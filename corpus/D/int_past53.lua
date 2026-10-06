-- surface: integers values past 2^53
local two53 = 1 << 53
local n = two53 + 1
print(math.type(two53), two53)
print(math.type(n), n)
print(n == 9007199254740993)
print((two53 + 0.0) == (two53 + 1.0))
print(math.type(two53 + 0.0))
