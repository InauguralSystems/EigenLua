-- surface: goto
local x = 0
goto skip
x = 1
::skip::
print(x)
local n = 0
::again::
n = n + 1
if n < 3 then goto again end
print(n)
