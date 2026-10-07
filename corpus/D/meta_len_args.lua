-- surface: metatables: __len, like the unary __unm and __bnot, receives its operand twice (lvm.c luaV_objlen, luaT_callTMres)
local function show(name)
  return function(...)
    local n = select("#", ...)
    local a, b = ...
    print(name, n, a == b, rawequal(a, b))
    return 7
  end
end
local t = setmetatable({}, {__len = show("len"), __unm = show("unm"), __bnot = show("bnot")})
print(#t, -t, ~t)
local s = setmetatable({}, {__len = function(a, b) return rawequal(a, b) and "same" or "other" end})
print(#s)
