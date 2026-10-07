-- surface: table library: table.remove and table.insert follow ltablib.c tremove/tinsert, position checks and t[0] included
local t = {[0] = "ban"}
print(#t, table.remove(t), t[0])
local t2 = {}
print(table.remove(t2), #t2)
local t3 = {1, 2, 3}
print(table.remove(t3, 4), #t3)
print(pcall(table.remove, t3, 5))
print(table.remove(t3, 1), t3[1], t3[2], #t3)
local t4 = {[0] = "z"}
print(table.remove(t4, 0), t4[0])
print(pcall(table.remove, {}, -1))
print(table.remove({}, 1))
print(pcall(table.remove, {}, 2))
local t5 = {"a", "b"}
table.insert(t5, 1, "x")
table.insert(t5, 4, "y")
print(table.concat(t5, ","))
print(pcall(table.insert, t5, 6, "z"))
print(pcall(table.insert, t5, 0, "z"))
print(pcall(table.insert, t5, 1, 2, 3))
print(pcall(table.insert, t5))
table.insert(t5, 2, nil)
print(#t5, t5[1], t5[2], t5[3])
