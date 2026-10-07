-- surface: syntax errors: break outside a loop is reported where the enclosing function closes (EigenLua#5 e)
local cases = {
  "break",
  "if x then break end",
  "local function f()\n  if x then\n    break\n  end\n  return 1\nend\n",
  "do\n  break\nend\nprint(1)\n",
  "while true do end\nif a then\n\n break\nend\n\n",
  "local function f() break end",
  "function g()\n\n break\n\nend",
  "x = function()\n do\n break\n end\n\n end",
  "for i = 1, 2 do\n  local function h()\n    break\n  end\nend\n",
  "break\nbreak\n",
}
for i, c in ipairs(cases) do
  print(i, load(c, "=c"))
end
-- a break inside a loop, even a nested function's own loop, is fine
print(load("while true do break end local function k() for i = 1, 2 do break end end", "=c") ~= nil)
