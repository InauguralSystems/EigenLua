-- surface: tables nil holes
-- With holes, # may return any border (manual 3.4.7), so print whether the
-- result IS a border, never the number itself.
local function isborder(t, n)
  return (n == 0 or t[n] ~= nil) and t[n + 1] == nil
end
local t = {1, 2, 3, 4}
t[2] = nil
t[3] = nil
print(isborder(t, #t))
print(t[1], tostring(t[2]), tostring(t[3]), t[4])
local u = {}
u[1] = "a"
u[3] = "c"
print(isborder(u, #u))
print(u[1], tostring(u[2]), u[3])
local e = {nil, nil}
print(#e == 0 or isborder(e, #e))
