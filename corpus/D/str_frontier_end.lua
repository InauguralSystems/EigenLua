-- surface: string library: frontier patterns at the subject's end, where the next character is '\0' (%z), and empty matches in gmatch/gsub
print(string.gsub("aaa bbb", "%f[%W]", "|"))
print(string.gsub("aaa bbb", "%f[%z]", "|"))
print(string.gsub("aaa bbb", "%f[%Z]", "|"))
print(string.gsub("aaa bbb", "%f[^%z]", "|"))
print(string.find("abc", "%f[%z]"))
local t = {}
for w in string.gmatch("aaa bbb", "%f[%w]%w*") do t[#t + 1] = w end
print(table.concat(t, "|") .. "|", #t)
t = {}
for w in string.gmatch("aaa bbb", "%w*%f[%z]") do t[#t + 1] = "<" .. w .. ">" end
print(table.concat(t), #t)
print(string.gsub("abc", "%a*", "-"))
print(string.gsub(" a b ", "%s*", "-"))
print(string.gsub("abc", "", "-"))
for k in string.gmatch("abc", "b*", 2) do io.write("[", k, "]") end print()
