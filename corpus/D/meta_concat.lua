-- surface: metatables __concat
local mt = {
  __concat = function(a, b)
    local bs = b
    if type(b) == "table" then bs = b.s end
    return a.s .. "+" .. bs
  end
}
local a = setmetatable({s = "A"}, mt)
local b = setmetatable({s = "B"}, mt)
print(a .. b)
print(a .. "Z")
