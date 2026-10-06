-- surface: number to string conversion of floats and integers, through print and tostring (graded on purpose)
-- The float format is Lua's LUAI_NUMFFORMAT "%.14g", plus ".0" when the result
-- looks like an integer; both arms share the C printf. NaN is never printed,
-- because its sign is not specified.
local vals = {
  0.1, 1/3, 2/3, 1e15, 1e16, 123456789012345.0, 1e100, -0.0, 2^53, 2^63,
  math.pi, -math.pi, 1/0, -1/0, math.huge, math.mininteger,
  math.maxinteger + 0.0, 3 // 0.0,
}
for i = 1, #vals do print(i, vals[i], tostring(vals[i]), math.type(vals[i])) end
print(0/0 ~= 0/0, tostring(1e15) == "1e+15", tostring(-0.0))
print(1e15, 1e16, 2^53, math.maxinteger, math.mininteger)
