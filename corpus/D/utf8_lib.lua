-- surface: utf8 char codepoint len offset codes and charpattern
local s = utf8.char(72, 233, 8364, 128512, 33)
print(#s, utf8.len(s))
print(utf8.codepoint(s, 1, -1))
print(utf8.codepoint(s, 2))
print(utf8.len(s, 2), utf8.len(s, 4), utf8.len(""))
print(utf8.len("ab\xffcd"))
print(utf8.len("\xe2\x82"))
print(utf8.offset(s, 3), utf8.offset(s, -1), utf8.offset(s, 6), utf8.offset(s, 7))
local cps = {}
for p, c in utf8.codes(s) do cps[#cps + 1] = p .. ":" .. c end
print(table.concat(cps, " "))
print(string.byte(utf8.charpattern, 1, -1))
local n = 0
for ch in string.gmatch(s, utf8.charpattern) do n = n + 1 end
print(n)
print((pcall(utf8.codepoint, "\xff")), (pcall(utf8.codepoint, "a")))
