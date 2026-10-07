-- surface: load with a reader, pieces of 1, 2, 3 and 7 characters: a table constructor looks ahead only past a name (lparser.c field), an assignment to a <const>/<close> local is raised at its '=' or ',' and a function statement's after its body (check_readonly), and an unknown attribute after the '>' and the token after it are read (getlocalattribute); the readonly check sees the scopes lparser.c does, a repeat body's included in its condition
local function probe(src, k)
  local n, pos = 0, 1
  local f, e = load(function()
    n = n + 1
    local p = src:sub(pos, pos + k - 1)
    pos = pos + k
    return p
  end)
  print(k, n, f and "ok" or e)
end
for _, s in ipairs{"x = {1,,3}", "local a <const> = 1; a = 2; print(1)", "local a <foo> = 1 print(2)", "x = {a=1,,3}", "x = {[1]=2,,}", "local t = {1, 2 3}", "local c <const> = 1 c, d = 2, 3", "local c <close> = nil local function f() c = 1 end"} do
  for _, k in ipairs{1, 2, 3, 7} do probe(s, k) end
end
local function try(s)
  local f, e = load(s)
  print(e)
end
try("local a <const> = 1\nlocal function g() return function()\n a\n =\n 2 end end")
try("local a <close> = nil\nfunction a()\n\nend\n\nprint(1)")
try("local a <const> = 1\nfunction a.b()\nend")
try("local a <const> = 1\ndo local a = 2; a = 3 end\nb, a\n, c = 1")
try("local a <const> = 1\n x.y, a = 1")
try("local a <const> = 1\n local x = function(a) a = 2 end")
try("local a <const> = 1\n for a = 1, 2 do a = 3 end")
try("local a <const> = 1\n for k, a in pairs{} do a = 3 end; a = 4")
try("local a <foo\n>\n = 1")
try("local x <const>, y <close>, z = 1 y = 1")
try("local x <const> = 1 repeat local x = 2 until (function() x = 3 end)")
try("local x <const> = 1; x = 1 + {1,,}")
try("local x <const>, x = 1; x = 2")
