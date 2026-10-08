-- surface: errored coroutines with deferred closes do not retain live EigenScript tasks
local N = 2000
for i = 1, N do
  local co = coroutine.create(function()
    local x <close> = setmetatable({}, {__close = function() end})
    error("e", 0)
  end)
  local ok = coroutine.resume(co)
  if ok then print("unexpected") end
end
collectgarbage()
print("done", N)
