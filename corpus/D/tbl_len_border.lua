-- surface: tables length border
-- # is printed only while the table is a sequence; after a hole is made, the
-- program prints whether # returned a border (manual 3.4.7).
local function isborder(t, n)
  return (n == 0 or t[n] ~= nil) and t[n + 1] == nil
end
local t = {10, 20, 30}
print(#t)
t[4] = 40
print(#t)
t[6] = 60
print(isborder(t, #t))
print(tostring(t[5]))
t[5] = 50
print(#t)
t[6] = nil
print(#t)
