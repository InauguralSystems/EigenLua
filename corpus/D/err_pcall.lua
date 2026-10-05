-- surface: pcall and error
local ok, err = pcall(function() error("plain") end)
print(ok)
print(type(err) == "string")
print(string.match(err, "plain$") ~= nil)
ok, err = pcall(error, "direct", 0)
print(ok)
print(err)
