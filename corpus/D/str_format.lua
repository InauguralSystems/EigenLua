-- surface: strings string.format
print(string.format("%d %s %q %x %%", 255, "ok", "a\"b", 255))
print(string.format("%05d", 42))
print(string.format("%.3f", 1.5))
print(string.format("%q", "a\0b"))
