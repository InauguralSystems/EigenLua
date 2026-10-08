-- surface: attempt-to-index variable descriptions recognize explicit accesses through the _ENV upvalue or a local named _ENV as globals, while an alias remains a field
print(pcall(function() return _ENV.kk.x end))
print(pcall(function() return _ENV["kk"].x end))
local K <const> = "kk"
print(pcall(function() return _ENV[K .. ""].x end))
local e = _ENV
print(pcall(function() return e.kk.x end))

do
    local outer = _ENV
    local _ENV = outer
    print(outer.pcall(function() return _ENV.local_name.x end))
    print(outer.pcall(function() return _ENV["local_key"].x end))
    local alias = _ENV
    print(outer.pcall(function() return alias.local_alias.x end))
end
