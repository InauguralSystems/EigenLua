-- surface: the C-stack count across yield and resume (ldo.c lua_resume, precover): a resumed coroutine counts from its resumer's level plus one; a pcall that catches an error after its coroutine yielded and was resumed inside it restores the resume's level, not its own
local function depth()
  local d = 0
  local function r() d = d + 1 return pcall(r) end
  r()
  return d
end
print("main", depth())
local co = coroutine.wrap(function()
  print("in co", depth())
  pcall(function()
    pcall(function()
      coroutine.yield()
      print("after resume", depth())
      error("x")
    end)
    print("after inner error", depth())
    coroutine.yield()
    print("after second resume", depth())
  end)
  print("after outer pcall", depth())
end)
co()
co()
local function deep(n) if n == 0 then return co() end return pcall(deep, n - 1) end
deep(20)
