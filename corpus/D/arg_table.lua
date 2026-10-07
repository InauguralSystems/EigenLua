-- surface: the stand-alone interpreter's global 'arg' (lua.c createargtable): arg[0] is the script name, no arguments follow it, and the main chunk's '...' is empty
print(type(arg), #arg, arg[0], arg[1], select("#", ...))
print(arg[-1] ~= nil, rawlen(arg))
