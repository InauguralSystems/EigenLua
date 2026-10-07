-- surface: os.exit takes a boolean or an optional integer (loslib.c os_exit, luaL_optinteger): other arguments raise, and a numeric string converts
print(pcall(os.exit, "bad"))
print(pcall(os.exit, {}))
print(pcall(os.exit, 1.5))
print(pcall(os.exit, "x", true))
io.write("exiting\n")
os.exit("3")
