-- surface: to-be-closed variables: during error unwinding __close is called from the protected call, a C function (ldo.c luaD_pcall; coroutine.lua:238)
local Y, X
local function foo()
  local x <close> = setmetatable({}, {__close = function(_, err) Y = debug.getinfo(2); X = err end})
  error(43)
end
print(pcall(foo))
print(X, Y.what, Y.short_src, Y.currentline)

local co = coroutine.create(function() return pcall(foo) end)
print(coroutine.resume(co))
print(X, Y.what, Y.short_src, Y.currentline)

-- an error inside __close replaces the error being propagated
local function bar()
  local x <close> = setmetatable({}, {__close = function(_, err) error("in close: " .. tostring(err), 0) end})
  error("first", 0)
end
print(pcall(bar))
