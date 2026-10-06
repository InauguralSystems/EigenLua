-- surface: strings gsub with string, function and table replacement, %1 and %%, the n limit, and the count
print(string.gsub("hello world", "o", "0"))
print(string.gsub("hello world", "(%w+)", "<%1>"))
print(string.gsub("hello world", "%w+", "%0 %0", 1))
print(string.gsub("50 percent", "%d+", "%0%%"))
print(string.gsub("abc", "", "-"))
print(string.gsub("hello world", "(%w+) (%w+)", "%2 %1"))
print(string.gsub("x=1, y=2", "(%w+)=(%w+)", function(k, v) return v .. "=" .. k end))
print(string.gsub("a b c", "%a", function(c) if c == "b" then return nil end return c:upper() end))
local t = {name = "lua", ver = "5.4"}
print(string.gsub("$name $ver $none", "%$(%w+)", t))
print(string.gsub("aaa", "a", "b", 2))
print(string.gsub("aaa", "a", "b", 0))
print(select("#", string.gsub("x", "x", "y")))
-- subject over 64 bytes
local long = string.rep("one two three ", 6)
print(#long, string.gsub(long, "t(%a+)", "T%1"))
print(string.gsub(long, "%a+", function(w) return #w end))
print(string.gsub(long, "o", "0", 7))
