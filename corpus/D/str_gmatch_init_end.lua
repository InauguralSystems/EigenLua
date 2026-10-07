-- surface: string.gmatch with an init past the subject's end yields nothing, not even an empty match (lstrlib.c gmatch: init = ls + 1); find/match return fail there
local function all(s, p, i) local t = {} for a in string.gmatch(s, p, i) do t[#t + 1] = "<" .. a .. ">" end return #t .. ":" .. table.concat(t) end
for _, i in ipairs({-20, -9, -8, -1, 0, 1, 7, 8, 9, 10, 100}) do
  print(i, all("11 21 31", "%w*", i), all("11 21 31", "", i), all("", "", i))
  print(string.find("11 21 31", "", i), string.find("11 21 31", "%w*", i), string.match("11 21 31", "()", i))
  print(string.find("abc", "", i, true), (string.gsub("abc", "", "-")))
end
