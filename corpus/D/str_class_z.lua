-- surface: string library: %z is still the NUL class in Lua 5.4 (lstrlib.c match_class), %Z its complement
print(string.match("z", "%z"))
print(string.find("zzz", "%z"))
print(string.match("abc", "[%z]"))
print(string.find("abc", "%Z+"))
print(string.match("zap", "[^%z]+"))
print(string.gsub("hello", "%Z", "."))
print(string.match("z", "z"), string.match("Z", "%Z"))
