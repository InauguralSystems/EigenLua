-- surface: bounded non-string table-key churn with one live key
-- At most one identity key is live while many short-lived keys churn.
-- Correctness only: the memory bound is gated by tools/fuzz/mem_bound.sh.
local s = {}
for i = 1, 50000 do local o = {}; s[o] = true; s[o] = nil end
local live = {}; s[live] = true
local n, alltrue = 0, true
for _, value in pairs(s) do n = n + 1; alltrue = alltrue and value end
print(n, alltrue, s[live], rawlen(s))
