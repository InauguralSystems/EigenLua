-- surface: sparse geometric integer keys after non-integral numeric keys
-- A bank of non-integral keys must not make huge integer slot padding dense.
local t = {}
for i = 1, 500 do t[i + 0.5] = i end
local k = 0
for i = 1, 14 do k = 2 * (k + 501); t[k] = i end
local n, sum = 0, 0
for key, value in pairs(t) do n = n + 1; sum = sum + value end
print(n, sum, k, t[k], t[1.5], t[500.5])
