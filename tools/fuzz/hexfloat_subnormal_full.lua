-- surface: hexadecimal float numerals near the subnormal range (2^-1076..2^-1020, printed exactly as integer multiples of 2^-1074), 14 to 23 significant digits, from a fixed-seed generator: tonumber and a numeral in loaded source both round once, at the result's precision (strtod), the subnormal precision included
local x = 12345
local function nxt()
  x = (x * 69069 + 1) % 4294967296
  return x // 268435456
end
local hexd = "0123456789abcdef"
local bad = 0
for i = 1, 3000 do
  local k = 14 + nxt() % 10
  local d1 = 1 + nxt() % 15
  local t = {hexd:sub(d1 + 1, d1 + 1)}
  for j = 2, k do
    local d = nxt()
    t[#t + 1] = hexd:sub(d + 1, d + 1)
  end
  local top = -1076 + (nxt() * 16 + nxt()) % 57
  local s = "0x" .. table.concat(t) .. "p" .. (top - 4 * k + 4)
  local v = tonumber(s)
  local w = load("return " .. s)()
  -- v * 2^1074 is an integer below 2^54: it names the double exactly
  print(s, string.format("%d", v * 2^537 * 2^537), v == w)
end
print(string.format("%.17g", tonumber('0x6802b8098be00bbp-1081')))
print(string.format("%.17g %.17g %.17g", tonumber('0x1p-1074'), tonumber('0x1.0000000000001p-1075'), tonumber('0x3p-1076')))
print(string.format("%.17g %.17g", tonumber('0x1.fffffffffffff8p0'), tonumber('0x1.fffffffffffff7ffffp0')))
