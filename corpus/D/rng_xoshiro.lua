-- surface: math.random xoshiro256** with an explicit seed (manual, math.random)
-- Floats print with %.17g so every bit of the double is shown.
math.randomseed(42)
local f = {}
for i = 1, 10 do f[i] = string.format("%.17g", math.random()) end
print(table.concat(f, " "))
local r = {}
for i = 1, 10 do r[i] = math.random(1, 100) end
print(table.concat(r, " "))
for i = 1, 5 do print(math.random(0)) end
print(math.randomseed(42, 7))
print(math.random(0), math.random(1, 6), string.format("%.17g", math.random()))
