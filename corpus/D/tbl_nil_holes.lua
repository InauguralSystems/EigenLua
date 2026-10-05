-- surface: tables nil holes
local t = {1, 2, 3, 4}
t[2] = nil
t[3] = nil
print(#t)
print(t[1], tostring(t[2]), tostring(t[3]), t[4])
local u = {}
u[1] = "a"
u[3] = "c"
print(#u)
print(u[1], u[3])
