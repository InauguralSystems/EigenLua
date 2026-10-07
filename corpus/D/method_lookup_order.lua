-- surface: method calls: o:m(args) looks up o.m before it evaluates args (EigenLua#5 d)
local log = {}
local o = setmetatable({}, {__index = function(t, k)
  log[#log + 1] = "lookup " .. k
  return function(self, ...) log[#log + 1] = "call " .. k .. " " .. select("#", ...) end
end})
local function arg(n) log[#log + 1] = "arg" .. n; return n end
o:m(arg(1), arg(2))
print(table.concat(log, ","))
log = {}
local r = o:n(arg(3))
print(table.concat(log, ","))
log = {}
local function id(...) return ... end
id(o:p(arg(4)), o:q(arg(5)))
print(table.concat(log, ","))
