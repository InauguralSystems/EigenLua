-- surface: string.pack/unpack: signed integers of 5 to 7 bytes sign-extend exactly (lstrlib.c unpackint)
for i = 1, 8 do
  local s = string.rep("\xff", i)
  print(i, string.unpack("i" .. i, s), string.unpack(">i" .. i, s))
end
-- values whose packed bytes hold no zero byte (gaps/nul-in-string.eigs)
for _, v in ipairs({-1, -2, -255, -257, -65537, -16843010}) do
  local out = {}
  for _, n in ipairs({5, 6, 7, 8}) do
    local ok, x = pcall(string.unpack, "<i" .. n, string.pack("<i" .. n, v))
    out[#out + 1] = string.format("%.0f", x)
  end
  print(string.format("%.0f", v), table.concat(out, " "))
end
print(string.unpack("<I6", string.rep("\xff", 6)) == 2^48 - 1)
