-- surface: math fmod signed zero-divisor and mixed operands, ult sign-boundary comparisons, and string reverse empty multibyte and NUL bytes
local function show(label, f, ...)
  local r = table.pack(pcall(f, ...))
  io.write(label)
  for i = 1, r.n do io.write("\t", tostring(r[i])) end
  io.write("\n")
end

show("fmod -7 3", math.fmod, -7, 3)
show("fmod 7 -3", math.fmod, 7, -3)
show("fmod -7 -3", math.fmod, -7, -3)
show("fmod int zero", math.fmod, 7, 0)
show("fmod float zero", math.fmod, 7.0, 0.0)
show("fmod mixed float dividend", math.fmod, 7.5, 2)
show("fmod mixed float divisor", math.fmod, 7, 2.5)

show("ult negative positive", math.ult, -1, 1)
show("ult positive negative", math.ult, 1, -1)
show("ult min zero", math.ult, math.mininteger, 0)
show("ult zero min", math.ult, 0, math.mininteger)
show("ult max negative", math.ult, math.maxinteger, -1)
show("ult negative max", math.ult, -1, math.maxinteger)

print("reverse empty", string.reverse("") == "")
print("reverse multibyte", string.reverse("A\xc3\xa9\xe2\x82\xacZ"))
local nul = string.reverse("a\0bc")
print("reverse NUL", #nul, string.byte(nul, 1, -1))
