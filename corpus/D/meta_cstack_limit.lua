-- surface: LUAI_MAXCCALLS (200): metamethods, calls from C functions, pcall, the generic for's iterator and coroutine resumes each take a C level (ldo.c ccall, lua_resume); __call takes none; the limit raises "C stack overflow"
local d = 0
local t = setmetatable({}, {__index=function(t,k) d = d + 1 return t[k+1] end}); print(pcall(function() return t[1] end)) print(d)
d = 0
local function f() d = d + 1 return pcall(f) end
local r = table.pack(f()) print(r.n, r[r.n]) print(d)
d = 0
local u = setmetatable({}, {__newindex=function(t,k,v) d = d + 1 t[k+1] = v end}); print(pcall(function() u[1] = 1 end)) print(d)
d = 0
local a = setmetatable({}, {__add=function(x,y) d = d + 1 return x + y end}); print(pcall(function() return a + 1 end)) print(d)
d = 0
local c = setmetatable({}, {__call=function(self, n) d = d + 1 if n > 300 then return n end return self(n+1) end}); print(pcall(c, 1)) print(d)
d = 0
local function g(x, y) d = d + 1 local t = {2,1} table.sort(t, g) return x < y end
print(pcall(g, 1, 2)) print(d)
d = 0
local function it(s, i) d = d + 1 for k in it, nil, nil do end end
print(pcall(it)) print(d)
d = 0
local ts = setmetatable({}, {__tostring=function(s) d = d + 1 return tostring(s) end}); print(pcall(tostring, ts)) print(d)
d = 0
local function co() d = d + 1 local c = coroutine.wrap(co) return c() end
print(pcall(co)) print(d)
d = 0
local function gs() d = d + 1 return (string.gsub("a", "a", gs)) end
print(pcall(gs)) print(d)
local function probe() local d=0; local t=setmetatable({}, {__index=function(t,k) d=d+1 return t[k+1] end}); pcall(function() return t[1] end) return d end
print(probe())
print(coroutine.wrap(probe)())
print(coroutine.wrap(function() return coroutine.wrap(probe)() end)())
local co = coroutine.create(function() coroutine.yield(probe()) return probe() end)
print(coroutine.resume(co)) print(coroutine.resume(co))
print(pcall(probe))
