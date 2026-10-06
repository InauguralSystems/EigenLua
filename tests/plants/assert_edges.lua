-- Plant assert-edges: assert reached through a local alias, through pcall,
-- failing with a string, nil and a table. `calls` counts every assert call by
-- hand; lua-count's EIGENLUA-ASSERTS must equal it, and stdout must equal the
-- pristine build's.
local assert = assert
local calls = 0
calls = calls + 1; assert(true)
calls = calls + 1; print("returns", assert(1, "two", nil))
calls = calls + 1; print("e1", pcall(assert, false, "msg"))
calls = calls + 1; print("e2", pcall(function() assert(false, "msg") end))
calls = calls + 1; print("e3", pcall(assert, nil))
local ok, e = pcall(assert, false, {})
calls = calls + 1
print("e4", ok, type(e))
calls = calls + 1; print("e5", pcall(assert))
for i = 1, 3 do calls = calls + 1; assert(i) end
print("calls=" .. calls)
