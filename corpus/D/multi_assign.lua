-- surface: multiple assignment
local a, b, c = 1, 2
print(a, b, tostring(c))
a, b = b, a
print(a, b)
local t = {}
t[1], t[2], t[3] = 4, 5
print(t[1], t[2], tostring(t[3]))
local function g() return 8, 9 end
a, b, c = g(), 7
print(a, b, tostring(c))
