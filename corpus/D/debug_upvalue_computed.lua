-- surface: debug: getupvalue/setupvalue work on every Lua closure, however the debug function was reached (ldebug.c aux_upvalue)
local up = 5
local function f() return up end
local get = debug["get" .. "upvalue"]
local set = debug["set" .. "upvalue"]
print(get(f, 1))
print(set(f, 1, 7), f(), up)
print(get(f, 2))

-- upvalues are numbered by first reference; _ENV is one when a global is used
local a, b = 1, 2
local function g() local s = b + a; print(s) end
print(get(g, 1), get(g, 2), (get(g, 3)))
local function h() return a end
print(get(h, 1))

-- a loaded chunk's single upvalue is _ENV
local chunk = load("return x")
print(select(2, get(chunk, 1)) == _G)
set(chunk, 1, {x = "from new env"})
print(chunk())

-- functions without upvalues and C functions
print(get(function() return 1 end, 1))
print(select("#", get(print, 1)))
