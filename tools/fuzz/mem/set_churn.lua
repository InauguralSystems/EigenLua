-- 400k short-lived identity keys churn through one table; at most one is live.
local s = {}
for i = 1, 400000 do local o = {}; s[o] = true; s[o] = nil end
local live = {}; s[live] = true
local n = 0
for _ in pairs(s) do n = n + 1 end
print(n, s[live])
