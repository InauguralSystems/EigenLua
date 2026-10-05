-- surface: metatables __newindex
local store = {}
local t = setmetatable({}, {
  __newindex = function(_, key, value)
    store[key] = value * 2
  end
})
t.a = 3
t.b = 5
print(tostring(rawget(t, "a")))
print(store.a, store.b)
