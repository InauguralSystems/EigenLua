-- surface: every Lua 5.4 operator over a fixed value set, plus truthiness and select('#')
-- One line per case: operator, operand indices, then `err` or type and value.
-- The operator table below must name every token on the `operators:` line of
-- corpus/D.manifest (tools/grade.sh checks both directions). Unary - and ~
-- are spelled u- and u~ there. No error text, address or NaN sign is printed.
local T = {}
local V = {
  nil, false, true, 0, 1, -1, 0.0, -0.0, 1.5, math.maxinteger, math.mininteger,
  "", "a", "10", "0x10", "1e1", T,
}
local NV = 17
local function show(r)
  local t = type(r)
  if t == "number" then
    if r ~= r then return "number nan" end
    if math.type(r) == "integer" then return "integer " .. string.format("%d", r) end
    return "float " .. string.format("%.17g", r)
  elseif t == "string" then return "string " .. string.format("%q", r)
  elseif t == "table" then return rawequal(r, T) and "table T" or "table other"
  end
  return t .. " " .. tostring(r)
end
local function run(f, ...)
  local ok, r = pcall(f, ...)
  if not ok then return "err" end
  return show(r)
end
local unary = {
  {"not", function(a) return not a end},
  {"u-", function(a) return -a end},
  {"#", function(a) return #a end},
  {"u~", function(a) return ~a end},
}
local binary = {
  {"+", function(a, b) return a + b end},
  {"-", function(a, b) return a - b end},
  {"*", function(a, b) return a * b end},
  {"/", function(a, b) return a / b end},
  {"//", function(a, b) return a // b end},
  {"%", function(a, b) return a % b end},
  {"^", function(a, b) return a ^ b end},
  {"..", function(a, b) return a .. b end},
  {"==", function(a, b) return a == b end},
  {"~=", function(a, b) return a ~= b end},
  {"<", function(a, b) return a < b end},
  {"<=", function(a, b) return a <= b end},
  {">", function(a, b) return a > b end},
  {">=", function(a, b) return a >= b end},
  {"and", function(a, b) return a and b end},
  {"or", function(a, b) return a or b end},
  {"&", function(a, b) return a & b end},
  {"|", function(a, b) return a | b end},
  {"~", function(a, b) return a ~ b end},
  {"<<", function(a, b) return a << b end},
  {">>", function(a, b) return a >> b end},
}
for _, op in ipairs(unary) do
  for i = 1, NV do print(op[1], i, run(op[2], V[i])) end
end
for _, op in ipairs(binary) do
  for i = 1, NV do
    for j = 1, NV do print(op[1], i, j, run(op[2], V[i], V[j])) end
  end
end
for i = 1, NV do
  local v = V[i]
  if v then print("truthy", i, "T") else print("truthy", i, "F") end
  print("while-not", i, (function() local n = 0 while not v and n < 1 do n = n + 1 end return n end)())
end
local function none() end
local function three() return 1, nil, nil end
print("select#", select("#"), select("#", nil), select("#", nil, nil),
  select("#", none()), select("#", three()), select("#", (three())),
  select("#", table.unpack({1, nil, 3}, 1, 3)), select("#", none(), nil))
