-- surface: require: it asks each function of package.searchers in turn (loadlib.c findloader), preload first
package.path = "./no_such_dir_x/?.lua;;./no_such_dir_y/?/init.lua"
package.cpath = "./no_such_dir_z/?.so"
print(type(package.searchers), #package.searchers)
package.preload.mymod = function(...) print("loading", ...) return {v = 1} end
local m, extra = require("mymod")
print(m.v, extra, package.loaded.mymod == m)
print(require("mymod") == m, select("#", require("mymod")))

-- a searcher of our own, first in line
table.insert(package.searchers, 1, function(name)
  if name == "virt" then return function(n, x) return "virt:" .. n .. ":" .. tostring(x) end, "XD" end
  return "no virt '" .. name .. "'"
end)
print(require("virt"))
-- a module that returns nothing is stored as true
table.insert(package.searchers, 2, function(name)
  if name == "quiet" then return function() end end
end)
print(require("quiet"))
print(select(2, pcall(require, "nosuch.sub")))
print(package.searchpath("a.b", "./no_such_dir_x/?.lua;?.zz"))

package.searchers = nil
print(pcall(require, "zzz"))
package.searchers = {}
print(pcall(require, "zzz"))
