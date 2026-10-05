-- surface: metatables __call
local t = setmetatable({n = 10}, {
  __call = function(self, x, y) return self.n + x + y end
})
print(t(1, 2))
print(t(5, 0))
