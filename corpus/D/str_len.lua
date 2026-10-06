-- surface: strings length operator
print(#"")
print(#"abc")
print(#"a\0b")
print(#(string.char(0)))
print(#("xy"):rep(3))
