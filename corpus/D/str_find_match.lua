-- surface: strings find plain and pattern with init, match captures, position captures, gmatch
local s = "key = value; num = 42; x.y = 3.5"
print(string.find(s, "="))
print(string.find(s, "=", 5))
print(string.find(s, "x.y", 1, true))
print(string.find(s, ".", 1, true))
print(string.find(s, "(%a+) = (%d+)"))
print(string.find(s, "%d+", -4))
print(string.find(s, "nomatch"))
print(string.match(s, "(%a+) = (%a+)"))
print(string.match(s, "()num()"))
print(string.match(s, "%d+%.%d+"))
print(string.match("  trim me  ", "^%s*(.-)%s*$") .. "|")
print(string.match("abc", "^b"), string.match("abc", "c$"), string.match("abc", "^abc$"))
local words = {}
for w in string.gmatch("one two  three", "%a+") do words[#words + 1] = w end
print(#words, table.concat(words, ","))
local nums = {}
for a, b in string.gmatch("1=2, 30=40", "(%d+)=(%d+)") do nums[#nums + 1] = a .. ":" .. b end
print(table.concat(nums, " "))
local pos = {}
for p in string.gmatch("aXbXc", "()X") do pos[#pos + 1] = p end
print(table.concat(pos, " "))
