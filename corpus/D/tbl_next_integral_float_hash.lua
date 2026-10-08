-- surface: next keeps an integral float cursor distinct while locating an integer key in hash storage
local t = {}
t[1] = "one"
t[2.0] = "two"
t[3.5] = "fraction"
print(pcall(next, t, 1.0))
