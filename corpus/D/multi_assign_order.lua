-- surface: multiple assignment: every right-hand expression is evaluated left to right, surplus ones included (EigenLua#5 c)
local log = {}
local mt = {__index = function(t, k) log[#log + 1] = k; return k end}
local a = setmetatable({}, mt)
local b = setmetatable({}, mt)
local x = a.first, b.second
print(x, table.concat(log, ","))
log = {}
local p, q = a.one, b.two, a.three, b.four
print(p, q, table.concat(log, ","))
log = {}
local g1, g2
g1, g2 = b.k1, a.k2, b.k3
print(g1, g2, table.concat(log, ","))
log = {}
local t = {}
t.f = a.only, b.extra
print(t.f, table.concat(log, ","))
