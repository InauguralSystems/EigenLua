-- surface: syntax errors: lexical error messages and their "near" text follow llex.c (escapes, long brackets, numerals)
local cases = {
  [["abc\x"]], [["abc\xg"]], [["abc\x5"]], [["\xZZ"]],
  "x = [[abc", "x = [==[abc]]", "--[[ unfinished", "--[==[ x ]=]", "x = 1\n\n y = [[abc\n\n",
  [["a\z
   b"]], [["a\z  "]],
  [["\300"]], [["\256"]], [["\25"]], [["\999x"]], [["\1234"]],
  [["\u{110000000}"]], [["\u{12"]], [["\u12"]], [["\u{zz}"]], [["\u{7FFFFFFF}"]], [["\u{80000000}"]],
  [["abc]], [['abc]], "\"abc\ndef\"", [["\q"]], [["a\nb\q"]], "'abc\\",
  "x = 3e", "x = 0x", "x = 1..2", "x = 3.4.5", "x = 0xg", "x = 1e+", "x = 0x1p", "x = 3f", "x = 08", "x = 1_000",
  "x = @", "[=", "[==x", "x = [=[ ok ]=]",
}
for i, c in ipairs(cases) do
  local f, msg = load("return " .. c)
  if not f then f, msg = load(c) end
  print(i, f and "ok" or msg)
end
