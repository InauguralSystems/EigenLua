-- surface: traversed array shrink keeps implicit next cursors in linear time
local t = {}
for i = 1, 1000 do t["field" .. i] = i end
for i = 1, 20000 do t[i] = i end
local before = 0
for _, v in pairs(t) do before = before + v end
for i = 20000, 1, -1 do t[i] = nil end
local count = 0
for _ in pairs(t) do count = count + 1 end
print(before, count)
