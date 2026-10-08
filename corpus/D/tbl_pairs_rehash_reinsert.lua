-- surface: re-inserting a key after hash->array->hash migration must not shadow later live keys in pairs
local t = {}
for _ in pairs(t) do end     -- start the lazy order
t[2] = "x"                   -- hash
t.s = 1                      -- hash
t[1] = 1                     -- array grows, 2 migrates to the array
t[2] = nil                   -- array shrinks to 1
t[1] = nil                   -- array shrinks to 0
t[2] = "z"                   -- 2 back in the hash
local ks = {}
for k in pairs(t) do ks[#ks + 1] = tostring(k); if #ks > 10 then break end end
table.sort(ks)
print(#ks, table.concat(ks, " "))
