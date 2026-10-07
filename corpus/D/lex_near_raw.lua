-- surface: a syntax error names the token it met as the source spelled it (llex.c txtToken): numbers and strings by their raw text, the rest by their text
print(load("x = 1 2"))
print(load("x = 'a' 'b' 3"))
print(load("x = 1 + + 'str' 5"))
print(load("local t = {1, 2} t 0x10"))
