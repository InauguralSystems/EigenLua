-- surface: syntax: "\n", "\r", "\r\n" and "\n\r" each end one line, so line numbers in messages agree (llex.c inclinenumber)
local prog = "local a = 1 -- c\nlocal b = 2\n\n\nx = [=[\nhi\n]=]\ny = 'a\\\nb'\nreturn debug.getinfo(1).currentline\n"
for _, n in ipairs{"\n", "\r", "\n\r", "\r\n"} do
  local p, nn = string.gsub(prog, "\n", n)
  local f = load(p)
  print(nn, f(), #x, #y)
  print(load(string.gsub("local a = 1\n\nerror('boom')\n", "\n", n)) and select(2, pcall(load((string.gsub("local a = 1\n\nerror('boom')\n", "\n", n))))))
  print(select(2, load((string.gsub("local a\n\n\n= = 2", "\n", n)))))
end
