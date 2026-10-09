-- surface: LUAI_MAXCCALLS per C boundary kind (ldo.c ccall: luaD_call from lua_call/lua_pcall in library functions, luaT_callTM for metamethods, OP_TFORCALL, __close): __tostring, __concat, __eq, __lt, __le, __len, __unm, gsub with a function, format %s, __pairs, __index through table.concat/ipairs/unpack, __close, pcall, xpcall, load's reader, require, sort's comparator, math.max's __lt, coroutine.wrap and resume
local builtin_refs = {utf8.len}
local d
local function rep(name, ok, msg) print(name, d, ok, msg) end
d = 0 local T1 = setmetatable({}, {__tostring = function(t) d = d + 1 return tostring(t) end})
rep("tostring", pcall(tostring, T1))
d = 0 local T2 = setmetatable({}, {__concat = function(a, b) d = d + 1 return a .. b end})
rep("concat", pcall(function() return T2 .. "x" end))
d = 0 local T3 = setmetatable({}, {__eq = function(a, b) d = d + 1 return a == b end})
local T3b = setmetatable({}, getmetatable(T3))
rep("eq", pcall(function() return T3 == T3b end))
d = 0 local T4 = setmetatable({}, {__lt = function(a, b) d = d + 1 return a < b end})
rep("lt", pcall(function() return T4 < T4 end))
d = 0 local T5 = setmetatable({}, {__le = function(a, b) d = d + 1 return a <= b end})
rep("le", pcall(function() return T5 <= T5 end))
d = 0 local T6 = setmetatable({}, {__len = function(a) d = d + 1 return #a end})
rep("len", pcall(function() return #T6 end))
d = 0 local T7 = setmetatable({}, {__unm = function(a) d = d + 1 return -a end})
rep("unm", pcall(function() return -T7 end))
d = 0 local function g1(s) d = d + 1 return (string.gsub("x", "x", g1)) end
rep("gsub", pcall(g1, "x"))
d = 0 local T8 = setmetatable({}, {__tostring = function(t) d = d + 1 return string.format("%s", t) end})
rep("format %s", pcall(tostring, T8))
d = 0 local T9 = setmetatable({}, {__pairs = function(t) d = d + 1 for k in pairs(t) do end return next, t end})
rep("pairs", pcall(function() for k in pairs(T9) do end end))
d = 0 local T10 = setmetatable({}, {__index = function(t, k) d = d + 1 return table.concat(t) end})
T10[1] = nil
rep("concat-index", pcall(function() return table.concat(setmetatable({}, getmetatable(T10)), "", 1, 1) end))
d = 0 local T11 = setmetatable({}, {__index = function(t, k) d = d + 1 for i, v in ipairs(t) do end end})
rep("ipairs-index", pcall(function() for i, v in ipairs(T11) do end end))
d = 0 local T12 = setmetatable({}, {__index = function(t, k) d = d + 1 return table.unpack(t, 1, 1) end})
rep("unpack-index", pcall(table.unpack, T12, 1, 1))
d = 0 local function cl() d = d + 1 local x <close> = setmetatable({}, {__close = function() cl() end}) end
rep("close", pcall(cl))
d = 0 local function sel(...) d = d + 1 return select(1, pcall(sel)) end
rep("pcall-select", pcall(sel))
d = 0 local function xp() d = d + 1 return xpcall(xp, function(m) return m end) end
rep("xpcall", pcall(xp))
d = 0 local function ld() d = d + 1 return load(function() ld() return nil end) end
d = 0 local function rq() d = d + 1 package.preload["m" .. d] = rq return require("m" .. d) end
rep("require", pcall(rq))
d = 0 local function sorter() d = d + 1 table.sort({1, 2}, function(a, b) sorter() return a < b end) end
rep("sort", pcall(sorter))
d = 0 local function mx() d = d + 1 return math.max(setmetatable({}, {__lt = function() mx() end}), setmetatable({}, {__lt = function() mx() end})) end
rep("max-lt", pcall(mx))
d = 0 local function wr() d = d + 1 return coroutine.wrap(wr)() end
rep("wrap", pcall(wr))
d = 0 local function rs() d = d + 1 local co = coroutine.create(rs) local ok, e = coroutine.resume(co) error(e, 0) end
rep("resume", pcall(rs))
d = 0 local function dl() d = d + 1 return debug.traceback(setmetatable({}, {__tostring = dl})) end
d = 0 local function ld() d = d + 1 return load(function() ld() return nil end) end
print("load-reader", d, (pcall(ld)))
