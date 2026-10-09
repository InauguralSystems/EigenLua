-- surface: the table library on sequences (ltablib.c): concat with sep/i/j and its errors, insert at each position and its bound errors, remove at the end/front/#t+1/0 and on empty tables, sort with and without a comparator and its errors, move forward/backward/to another table, unpack with explicit i/j, pack
local builtin_refs = {os.date}
-- the table library over sequences: only specified results (no pairs order;
-- # only of sequences); errors through pcall with their messages
local function seq(t, n) local o = {} for i = 1, n or #t do o[i] = tostring(t[i]) end return "{" .. table.concat(o, ",") .. "}" end
local function try(name, f, ...) print(name, pcall(f, ...)) end
-- concat
print(table.concat({}), table.concat({1, 2, 3}), table.concat({"a", "b"}, ", "), table.concat({1, 2, 3}, "-", 2), table.concat({1, 2, 3}, "-", 2, 3), table.concat({1, 2, 3}, "-", 3, 2))
print(table.concat({1.5, "x", 10}, "|"), table.concat({"a"}, "-", 1, 1))
try("concat bad value", table.concat, {1, {}, 3})
try("concat hole", table.concat, {1, 2}, ",", 1, 3)
try("concat bad sep", table.concat, {1}, {})
try("concat meta", function() return table.concat(setmetatable({}, {__index = function(_, k) return "v" .. k end, __len = function() return 3 end}), " ") end)
-- insert
local t = {}
table.insert(t, "a") table.insert(t, "b") table.insert(t, 1, "c") table.insert(t, 2, "d") table.insert(t, #t + 1, "e")
print(seq(t))
try("insert pos 0", table.insert, {1, 2}, 0, "x")
try("insert pos past end", table.insert, {1, 2}, 4, "x")
try("insert 4 args", table.insert, {1}, 1, 2, 3)
try("insert 1 arg", table.insert, {1})
try("insert nontable", table.insert, "s", 1)
try("insert float pos", table.insert, {1, 2}, 1.5, "x")
-- remove
t = {1, 2, 3, 4}
print(table.remove(t), seq(t))
print(table.remove(t, 1), seq(t))
print(table.remove(t, #t + 1), seq(t))
print(table.remove({}), table.remove({}, 0), table.remove({}, 1))
try("remove pos past", table.remove, {1, 2}, 4)
try("remove pos -1", table.remove, {1, 2}, -1)
t = {[0] = "zero"}
print(table.remove(t, 0), t[0])
-- sort
t = {5, 2, 8, 1, 9, 3}
table.sort(t) print(seq(t))
table.sort(t, function(a, b) return a > b end) print(seq(t))
t = {"banana", "apple", "Cherry", "date"}
table.sort(t) print(seq(t))
t = {} for i = 1, 200 do t[i] = (i * 37) % 101 end
table.sort(t)
local ok = true for i = 2, 200 do if t[i - 1] > t[i] then ok = false end end
print("sorted 200", ok, t[1], t[200])
try("sort mixed", table.sort, {1, "x", 2})
try("sort bad cmp", table.sort, {1, 2}, 3)
try("sort invalid order", function() local u = {} for i = 1, 100 do u[i] = i % 7 end table.sort(u, function(a, b) return true end) end)
-- move
t = table.move({1, 2, 3}, 1, 3, 2) print(seq(t, 4))
t = table.move({1, 2, 3}, 2, 3, 1) print(seq(t, 3))
local dst = table.move({1, 2, 3}, 1, 3, 3, {}) print(seq(dst, 5))
t = table.move({1, 2}, 1, 0, 5) print(seq(t, 2))
try("move nontable", table.move, 1, 1, 1, 1)
-- unpack and pack
print(table.unpack({1, 2, 3}))
print(table.unpack({1, 2, 3}, 2))
print(table.unpack({1, 2, 3}, 2, 5))
print(table.unpack({1, 2, 3}, 3, 2))
print(select("#", table.unpack({}, 1, 3)))
print(table.unpack({"a", "b"}, -1, 1))
local p = table.pack(1, nil, 3)
print(p.n, p[1], p[2], p[3])
print(table.pack().n)
try("unpack too many", table.unpack, {}, 1, 1e8)
