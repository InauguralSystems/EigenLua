-- surface: coroutine.wrap closes pending variables before propagating an error
print(pcall(coroutine.wrap(function()
  local z <close> = setmetatable({}, {__close = function(_, e) print("z", e) end})
  error("we", 0)
end)))
