-- 14 geometric integer keys after 500 non-integral keys: slot padding must not
-- grow with the largest key.
local t = {}
for i = 1, 500 do t[i + 0.5] = i end
local k = 0
for i = 1, 14 do k = 2 * (k + 501); t[k] = i end
local n = 0
for _ in pairs(t) do n = n + 1 end
print(n, t[k])
