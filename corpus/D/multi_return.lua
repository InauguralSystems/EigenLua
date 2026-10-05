-- surface: multiple returns truncated or expanded by position
local function m() return 1, 2, 3 end
print(m())
local a, b = m()
print(a, b)
local t = {m()}
print(#t, t[1], t[2], t[3])
local u = {m(), 9}
print(#u, u[1], u[2])
print((m()))
local x, y, z, w = m()
print(x, y, z, tostring(w))
