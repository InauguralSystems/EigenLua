-- surface: the variable named in 'attempt to index' errors is the indexed value's (ldebug.c getobjname): a field read by name, 'integer index' for a small integer key, '?' for any other key, nothing for a call's result, and a parenthesized expression is named as its inner one; reads and assignments
local t = {}
print(pcall(function() return t.x.y end))
print(pcall(function() return pcall(print).y end))
print(pcall(function() return (t.x).y end))
print(pcall(function() return t[1].y end))
print(pcall(function() local a = t.q; return a.z end))
print(pcall(function() return ("x"):rep(1).y.z end))
local k = "q"
print(pcall(function() return t[k].z end))
print(pcall(function() return t["q"].z end))
print(pcall(function() return t[1.5].z end))
print(pcall(function() return t[true].z end))
print(pcall(function() return ((t.x)).y end))
print(pcall(function() return t.x[1] end))
print(pcall(function() return undefinedglobal.y end))
local up = nil
print(pcall(function() return up.y end))
print(pcall(function() return ("x").y.z end))
print(pcall(function() return #t.x end))
print(pcall(function() t.x.y = 1 end))
print(pcall(function() (t.x).y = 1 end))
print(pcall(function() pcall(print).y = 1 end))
