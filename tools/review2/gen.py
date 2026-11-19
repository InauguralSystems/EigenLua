# Five differentials, each expression three ways: L literal, V variables, D load.
import random, sys
R = random.Random(424242)
MAX, MIN = 2**63-1, -2**63

def ilit(v):
    if v == MIN: return "math.mininteger"
    if v < 0: return "(%d)" % v
    return "%d" % v

HDR = r'''local function fmt(ok, ...)
  if not ok then return "ERR " .. tostring((...)) end
  local t = table.pack(...) local s = {}
  for i = 1, t.n do local v = t[i]; s[#s+1] = (math.type(v) or type(v)) .. ":" .. tostring(v) end
  return table.concat(s, " ")
end
local function show(tag, ...) print(tag, fmt(...)) end
'''

def emit(out, tag, expr_lit, expr_var, params, args):
    # L: literal inside a function; V: variables as parameters; D: load of the literal text
    out.append("show(%r, pcall(function() return %s end))" % (tag + " L " + expr_lit.replace("\n", " ")[:70], expr_lit))
    out.append("show(%r, pcall(function(%s) return %s end, %s))" % (tag + " V", params, expr_var, args))
    out.append("show(%r, pcall(function() return load(%r)() end))" % (tag + " D", "return " + expr_lit))

def arith():
    vals = [0x7ffffffffffffff0, -0x7ffffffffffffff0, 3037000499, 3037000500, -3037000500, 2**32+7, -(2**32)-7,
            10**18, -10**18, 123456789012345678, -987654321098765432, MAX, MIN, MAX-2, MIN+3, 2**53+3, -(2**53)-5,
            6, -7, 1, -1, 0, 2**40+1, 2**62+5]
    ops = ["+", "-", "*", "//", "%", "<<", ">>", "&", "|", "~"]
    out = []; n = 0
    pool = []
    for op in ops:
        for _ in range(16):
            a = R.choice(vals); b = R.choice(vals)
            if op in ("<<", ">>"): b = R.choice([1, 2, 31, 32, 33, 62, 63, 64, 65, -1, -63, -64, 100, -100])
            if op in ("//", "%") and b == 0: b = 3
            pool.append((a, op, b))
    for v in vals: pool.append((v, "u-", None)); pool.append((v, "u~", None))
    for a, op, b in pool:
        n += 1; tag = "A%03d" % n
        if op == "u-": el, ev, pr, ar = "-%s" % ilit(a), "-x", "x", ilit(a)
        elif op == "u~": el, ev, pr, ar = "~%s" % ilit(a), "~x", "x", ilit(a)
        else: el, ev, pr, ar = "%s %s %s" % (ilit(a), op, ilit(b)), "x %s y" % op, "x, y", "%s, %s" % (ilit(a), ilit(b))
        emit(out, tag, el, ev, pr, ar)
    return n, out

def text():
    fl = ["1e14", "1e15", "123456789012.0", "0.1", "1/3", "-1/3", "2^-1074", "1e-310", "2^63*1.5", "-2^63", "2^63",
          "-0.0", "0.0", "1e300*10", "-(1e300*10)", "2^53+1.0", "100.0", "-100.0", "12345.678", "1e-5", "5e-324",
          "3.14159265358979", "2^24", "-2^31", "1e100/3"]
    ints = ["0", "-1", "math.maxinteger", "math.mininteger", "2^53|0", "-(2^53|0)-1", "0x7fff", "255", "-255",
            "1000000000000000000", "0xffffffffffffffff"]
    convs = ["tostring(x)", "x .. ''", "string.format('%s', x)", "string.format('%.3f', x)", "string.format('%g', x)",
             "string.format('%.17g', x)", "string.format('%q', x)", "string.format('%a', x)", "string.format('%10.2e', x)"]
    iconvs = ["tostring(x)", "x .. ''", "string.format('%d', x)", "string.format('%x', x)", "string.format('%X', x)",
              "string.format('%o', x)", "string.format('%5.3d', x)", "string.format('%q', x)", "string.format('%+d', x)",
              "string.format('%.0f', x)", "string.format('%i', x)"]
    out = []; n = 0
    for v in fl:
        for c in convs[:7] if v not in ("2^63*1.5",) else convs:
            n += 1; emit(out, "B%03d" % n, c.replace("x", "(%s)" % v, 1) if "x .." not in c else "(%s) .. ''" % v, c, "x", v)
    for v in ints:
        for c in iconvs:
            n += 1; emit(out, "B%03d" % n, c.replace("x", "(%s)" % v, 1) if "x .." not in c else "(%s) .. ''" % v, c, "x", v)
    return n, out

def keys():
    ks = ["1.0", "2^53", "-0.0", "2^63", "-2^63", "3.5", "1e300*10", "-(1e300*10)", "7.0", "2^31", "2^32+1.0", "-2^53",
          "math.maxinteger + 0.0", "2^62", "0.5", "-1.0", "1e15", "2^52+0.5"]
    alts = {"1.0": "1", "2^53": "2^53|0", "-0.0": "0", "-2^63": "math.mininteger", "7.0": "7", "2^31": "2^31|0",
            "2^32+1.0": "4294967297", "-2^53": "-(2^53|0)", "2^62": "2^62|0", "-1.0": "-1", "1e15": "10^15|0"}
    out = []; n = 0
    templates = [
      ("local t = {}; t[{K}] = 'v'; local k = next(t); return math.type(k), k", "local t = {}; t[k1] = 'v'; local k = next(t); return math.type(k), k"),
      ("local t = {}; t[{K}] = 'v'; return t[{A}]", "local t = {}; t[k1] = 'v'; return t[k2]"),
      ("local t = {[{K}] = 'w'}; local s = ''; for k, v in pairs(t) do s = s .. math.type(k) .. tostring(k) .. v end; return s", "local t = {[k1] = 'w'}; local s = ''; for k, v in pairs(t) do s = s .. math.type(k) .. tostring(k) .. v end; return s"),
      ("local t = {}; rawset(t, {K}, 1); return rawget(t, {A}), (next(t))", "local t = {}; rawset(t, k1, 1); return rawget(t, k2), (next(t))"),
      ("local t = {}; t[{K}] = 1; t[{K}] = nil; return next(t), t[{A}]", "local t = {}; t[k1] = 1; t[k1] = nil; return next(t), t[k2]"),
      ("local t = {[{A}] = 'a'}; t[{K}] = 'b'; local k, v = next(t); return math.type(k), k, v, next(t, k)", "local t = {[k2] = 'a'}; t[k1] = 'b'; local k, v = next(t); return math.type(k), k, v, next(t, k)"),
      ("local t = {}; t[{K}] = 3; local mt = 0; for k in pairs(t) do mt = math.type(k) end; return mt, rawlen(t)", "local t = {}; t[k1] = 3; local mt = 0; for k in pairs(t) do mt = math.type(k) end; return mt, rawlen(t)"),
      ("local t = {}; t[{A}] = 5; return t[{K}], rawequal(t[{K}], t[{A}])", "local t = {}; t[k2] = 5; return t[k1], rawequal(t[k1], t[k2])"),
      ("local t = {}; t[{A}] = 1; t[{K}] = 2; local c = 0; for _ in pairs(t) do c = c + 1 end; return c, t[{A}]", "local t = {}; t[k2] = 1; t[k1] = 2; local c = 0; for _ in pairs(t) do c = c + 1 end; return c, t[k2]"),
    ]
    for K in ks:
        A = alts.get(K, K)
        for tl, tv in templates:
            n += 1
            el = tl.replace("{K}", "(%s)" % K).replace("{A}", "(%s)" % A)
            out.append("show(%r, pcall(function() %s end))" % ("C%03d L" % n, el))
            out.append("show(%r, pcall(function(k1, k2) %s end, %s, %s))" % ("C%03d V" % n, tv, K, A))
            out.append("show(%r, pcall(function() return load(%r)() end))" % ("C%03d D" % n, el))
    # table functions with integral-float positions
    extra = [("local t = {10, 20, 30}; table.insert(t, 2.0, 15); return table.concat(t, ',')", "p"),
             ("local t = {10, 20, 30}; return table.remove(t, 3.0), #t", "p"),
             ("local t = {10, 20, 30}; return t[2.0], t[3.0 - 1.0], select('#', table.unpack(t, 1.0, 3.0))", "p"),
             ("local t = {}; t[1.0] = 'a'; t[2] = 'b'; return #t, t[1], t[2.0]", "p"),
             ("local t = {}; for i = 1.0, 3.0 do t[i] = i end; return #t, math.type(next(t))", "p"),
             ("local t = {'a', 'b'}; return table.concat(t, '-', 1.0, 2.0)", "p"),
             ("local t = setmetatable({}, {__index = function(_, k) return math.type(k) end}); return t[3.0], t[3.5], t[2^63]", "p"),
             ("local t = setmetatable({}, {__newindex = function(r, k, v) rawset(r, 'mt', math.type(k)) end}); t[4.0] = 1; return t.mt", "p"),
             ("local t = {}; t[2^53] = 1; t[2^53|0] = 2; local c = 0; for _ in pairs(t) do c = c + 1 end; return c, t[2^53]", "p"),
             ("local t = {}; local ok, e = pcall(function() t[0/0] = 1 end); return ok, e ~= nil", "p")]
    for e, _ in extra:
        n += 1
        out.append("show(%r, pcall(function() %s end))" % ("C%03d L" % n, e))
        out.append("show(%r, pcall(function() return load(%r)() end))" % ("C%03d D" % n, e))
        out.append("show(%r, pcall(function(f) return f() end, function() %s end))" % ("C%03d V" % n, e))
    return n, out

def nils():
    exprs = [
      ("type(x)", "nil"), ("tostring(x)", "nil"), ("x == nil", "nil"), ("x == false", "nil"), ("x ~= 0", "nil"),
      ("not x", "nil"), ("x or 5", "nil"), ("x and 5", "nil"), ("select('#', x)", "nil"), ("select('#', x, x)", "nil"),
      ("table.pack(x).n", "nil"), ("table.pack(x, x, 1).n", "nil"), ("string.format('%s|%5s|%-5s|', x, x, x)", "nil"),
      ("string.format('%q', x)", "nil"), ("tostring(x) .. 'z'", "nil"), ("rawequal(x, nil)", "nil"), ("math.type(x)", "nil"),
      ("tonumber('nil')", "nil"), ("x + 1", "nil"), ("1 - x", "nil"), ("x * 2.0", "nil"), ("x // 1", "nil"), ("x % 2", "nil"),
      ("-x", "nil"), ("#x", "nil"), ("x .. 'a'", "nil"), ("x < 1", "nil"), ("x <= x", "nil"), ("x & 1", "nil"), ("~x", "nil"),
      ("x()", "nil"), ("x.f", "nil"), ("x[1]", "nil"), ("({})[x]", "nil"), ("rawget({}, 1)", "nil"), ("rawlen({})", "nil"),
      ("next({}, x)", "nil"), ("type(next({}))", "nil"), ("ipairs(x)", "nil"), ("pairs(x)", "nil"), ("tostring(nil) == 'nil'", "nil"),
      ("math.floor(x)", "nil"), ("math.abs(x)", "nil"), ("math.max(1, x)", "nil"), ("string.rep('a', x)", "nil"),
      ("string.len(x)", "nil"), ("tonumber(x)", "nil"), ("select(-1, 1, x)", "nil"), ("select(2, 1, x, 3)", "nil"),
      ("setmetatable({}, x) ~= nil", "nil"), ("getmetatable(x)", "nil"), ("string.format('%d', x)", "nil"),
      ("table.concat({1, x, 3})", "nil"), ("table.unpack({x, 2}, 1, 2)", "nil"), ("select('#', table.unpack({x, x}, 1, 2))", "nil"),
      ("(function(...) return select('#', ...) end)(x, x, x)", "nil"), ("({x, 2})[2]", "nil"), ("({n = x}).n", "nil"),
      ("assert(x)", "nil"), ("error(x)", "nil"), ("string.format('%s', x == x)", "nil"), ("x == x", "nil"),
      ("tostring(x):upper()", "nil"), ("math.tointeger(x)", "nil"), ("utf8.char(x)", "nil"), ("string.char(x)", "nil"),
      ("coroutine.wrap(function(a) return a end)(x)", "nil"), ("select('#', coroutine.wrap(function(a) return a end)(x))", "nil"),
      ("next({x})", "nil"), ("load(x)", "nil"), ("string.sub('abc', x)", "nil"), ("string.sub('abc', 2, x)", "nil"),
      ("table.insert({}, x)", "nil"), ("os.time(x) ~= nil", "nil"), ("x ~= x", "nil"), ("x > x", "nil"),
    ]
    for op in ["+", "-", "*", "/", "//", "%", "^", "..", "==", "~=", "<", "<=", ">", ">=", "&", "|", "~", "<<", ">>", "and", "or"]:
        for other in ["1", "2.5", "'s'"]:
            exprs.append(("x %s %s" % (op, other), "nil"))
            exprs.append(("%s %s x" % (other, op), "nil"))
    out = []; n = 0
    for e, _ in exprs:
        n += 1
        el = e.replace("x", "nil") if "x" in e else e
        # keep identifiers like 'max', 'next' and 'xpcall' intact: substitute only the operand x
        import re
        el = re.sub(r"(?<![A-Za-z_.'])x(?![A-Za-z_'])", "(nil)", e)
        emit(out, "N%03d" % n, el, e, "x", "nil")
    return n, out

def kinds():
    out = []; n = 0
    ivals = ["7", "-7", "0", "math.maxinteger", "math.mininteger", "2^53|0"]
    fvals = ["7.0", "-7.0", "0.0", "-0.0", "2.5", "2^53", "1e300*10"]
    binops = ["+", "-", "*", "/", "//", "%", "^"]
    combos = [("7", "2"), ("7", "2.0"), ("7.0", "2"), ("7.0", "2.0"), ("-7", "2"), ("-7", "-2.0"), ("math.maxinteger", "1"),
              ("math.mininteger", "-1"), ("6", "3"), ("6.0", "3")]
    for a, b in combos:
        for op in binops:
            n += 1; emit(out, "E%03d" % n, "math.type((%s) %s (%s))" % (a, op, b), "math.type(x %s y)" % op, "x, y", "%s, %s" % (a, b))
    for a, b in [("3.0", "1"), ("3", "1.0"), ("3.0", "0"), ("-1.0", "1.0"), ("2^62", "1"), ("255.0", "15.0"), ("1.0", "64"), ("1", "64.0"), ("-1.0", "63")]:
        for op in ["<<", ">>", "&", "|", "~"]:
            n += 1; emit(out, "E%03d" % n, "math.type((%s) %s (%s))" % (a, op, b), "math.type(x %s y)" % op, "x, y", "%s, %s" % (a, b))
    for a in ["3.0", "-1.0", "0.0", "2^53"]:
        n += 1; emit(out, "E%03d" % n, "math.type(~(%s))" % a, "math.type(~x)", "x", a)
        n += 1; emit(out, "E%03d" % n, "math.type(-(%s))" % a, "math.type(-x)", "x", a)
    for a in ["3", "-3"]:
        n += 1; emit(out, "E%03d" % n, "math.type(-(%s))" % a, "math.type(-x)", "x", a)
    calls = [("utf8.codepoint('é')", "utf8.codepoint(x)", "'é'"), ("utf8.codepoint('a', 1.0)", "utf8.codepoint('a', x)", "1.0"),
             ("utf8.len('héllo')", "utf8.len(x)", "'héllo'"), ("utf8.offset('héllo', 3)", "utf8.offset(x, 3)", "'héllo'"),
             ("string.byte('A')", "string.byte(x)", "'A'"), ("string.byte('AB', 2.0)", "string.byte('AB', x)", "2.0"),
             ("#'abc'", "#x", "'abc'"), ("#{1, 2, 3}", "#x", "{1, 2, 3}"), ("select('#', 1, 2)", "select('#', x, x)", "1"),
             ("string.len('abcd')", "string.len(x)", "'abcd'"), ("string.find('abc', 'b')", "string.find(x, 'b')", "'abc'"),
             ("math.floor(3.7)", "math.floor(x)", "3.7"), ("math.floor(-3.5)", "math.floor(x)", "-3.5"), ("math.floor(2^62)", "math.floor(x)", "2^62"),
             ("math.floor(2^63)", "math.floor(x)", "2^63"), ("math.floor(1e300*10)", "math.floor(x)", "1e300*10"), ("math.floor(5)", "math.floor(x)", "5"),
             ("math.ceil(3.2)", "math.ceil(x)", "3.2"), ("math.ceil(-0.5)", "math.ceil(x)", "-0.5"), ("math.ceil(-2^63)", "math.ceil(x)", "-2^63"),
             ("math.ceil(1e300*10)", "math.ceil(x)", "1e300*10"), ("math.ceil(-(1e300*10))", "math.ceil(x)", "-(1e300*10)"),
             ("math.tointeger(3.0)", "math.tointeger(x)", "3.0"), ("math.tointeger(2^63)", "math.tointeger(x)", "2^63"),
             ("math.tointeger(-2^63)", "math.tointeger(x)", "-2^63"), ("math.tointeger('8')", "math.tointeger(x)", "'8'"),
             ("math.tointeger(3.5)", "math.tointeger(x)", "3.5"), ("math.tointeger(-0.0)", "math.tointeger(x)", "-0.0"),
             ("math.abs(-3)", "math.abs(x)", "-3"), ("math.abs(-3.0)", "math.abs(x)", "-3.0"), ("math.abs(math.mininteger)", "math.abs(x)", "math.mininteger"),
             ("math.abs(-0.0)", "math.abs(x)", "-0.0"), ("math.max(1, 2.0)", "math.max(1, x)", "2.0"), ("math.max(3, 2.0)", "math.max(x, 2.0)", "3"),
             ("math.min(1.0, 1)", "math.min(x, 1)", "1.0"), ("math.min(1, 1.0)", "math.min(x, 1.0)", "1"), ("math.max(math.mininteger, -2^63)", "math.max(x, -2^63)", "math.mininteger"),
             ("math.fmod(7, 3)", "math.fmod(x, 3)", "7"), ("math.fmod(7.0, 3)", "math.fmod(x, 3)", "7.0"), ("math.fmod(-7, 3)", "math.fmod(x, 3)", "-7"),
             ("math.fmod(7, -3.0)", "math.fmod(7, x)", "-3.0"), ("math.fmod(math.mininteger, -1)", "math.fmod(x, -1)", "math.mininteger"),
             ("math.fmod(1e308, 0.1)", "math.fmod(x, 0.1)", "1e308"), ("math.fmod(-1e300, 7)", "math.fmod(x, 7)", "-1e300"),
             ("math.fmod(2^60, 0.3)", "math.fmod(x, 0.3)", "2^60"), ("math.fmod(5.5, 2^-1000)", "math.fmod(5.5, x)", "2^-1000"),
             ("tonumber('42')", "tonumber(x)", "'42'"), ("tonumber('42.0')", "tonumber(x)", "'42.0'"), ("tonumber('0x10')", "tonumber(x)", "'0x10'"),
             ("tonumber('1e2')", "tonumber(x)", "'1e2'"), ("tonumber(' 9223372036854775807 ')", "tonumber(x)", "' 9223372036854775807 '"),
             ("tonumber('9223372036854775808')", "tonumber(x)", "'9223372036854775808'"), ("tonumber('-9223372036854775808')", "tonumber(x)", "'-9223372036854775808'"),
             ("tonumber('  -12  ')", "tonumber(x)", "'  -12  '"), ("tonumber('007')", "tonumber(x)", "'007'"), ("tonumber('-0')", "tonumber(x)", "'-0'"),
             ("tonumber('1' .. string.rep('0', 19))", "tonumber(x)", "'1' .. string.rep('0', 19)"), ("tonumber('ff', 16)", "tonumber(x, 16)", "'ff'"),
             ("tonumber('zz', 36)", "tonumber(x, 36)", "'zz'"), ("tonumber('7fffffffffffffff', 16)", "tonumber(x, 16)", "'7fffffffffffffff'"),
             ("tonumber(3.0)", "tonumber(x)", "3.0"), ("tonumber('0x1p4')", "tonumber(x)", "'0x1p4'"),
             ("string.format('%d', 3.0)", "string.format('%d', x)", "3.0"), ("string.format('%d', -0.0)", "string.format('%d', x)", "-0.0"),
             ("string.format('%d', 2^53)", "string.format('%d', x)", "2^53"), ("string.format('%d', 3.5)", "string.format('%d', x)", "3.5"),
             ("string.format('%d', 2^63)", "string.format('%d', x)", "2^63"), ("string.format('%d', '10')", "string.format('%d', x)", "'10'"),
             ("string.format('%x', 255.0)", "string.format('%x', x)", "255.0"), ("string.format('%d', -2^63)", "string.format('%d', x)", "-2^63"),
             ("'10' + 1", "x + 1", "'10'"), ("'10' * '2'", "x * '2'", "'10'"), ("'3.0' + 1", "x + 1", "'3.0'"), ("'0x10' + 0", "x + 0", "'0x10'"),
             ("'10' // 3", "x // 3", "'10'"), ("'10' | 0", "x | 0", "'10'"), ("'1e1' | 0", "x | 0", "'1e1'"), ("10 .. ''", "x .. ''", "10"),
             ("math.type(math.random(1, 10))", "math.type(math.random(x, 10))", "1"), ("string.rep('a', 3.0)", "string.rep('a', x)", "3.0"),
             ("select(2.0, 'a', 'b')", "select(x, 'a', 'b')", "2.0"), ("('abc'):sub(2.0)", "('abc'):sub(x)", "2.0"),
             ("math.ult(1, 2.0)", "math.ult(1, x)", "2.0"), ("table.unpack({1, 2}, 1.0, 2.0)", "table.unpack({1, 2}, x, 2.0)", "1.0"),
             ("string.pack('i4', 3.0):len()", "string.pack('i4', x):len()", "3.0"), ("utf8.char(72.0)", "utf8.char(x)", "72.0"),
            ]
    for el, ev, arg in calls:
        n += 1
        out.append("show(%r, pcall(function() local r = table.pack(%s); local s = {} for i = 1, r.n do s[i] = math.type(r[i]) or type(r[i]) end; return table.concat(s, ','), %s end))" % ("E%03d L %s" % (n, el[:60]), el, el))
        out.append("show(%r, pcall(function(x) local r = table.pack(%s); local s = {} for i = 1, r.n do s[i] = math.type(r[i]) or type(r[i]) end; return table.concat(s, ','), %s end, %s))" % ("E%03d V" % n, ev, ev, arg))
        src = "local r = table.pack(%s); local s = {} for i = 1, r.n do s[i] = math.type(r[i]) or type(r[i]) end; return table.concat(s, ','), %s" % (el, el)
        out.append("show(%r, pcall(function() return load(%r)() end))" % ("E%03d D" % n, src))
    return n, out

which = sys.argv[1]
n, out = {"arith": arith, "text": text, "keys": keys, "nil": nils, "kinds": kinds}[which]()
sys.stderr.write("%s: %d expressions, %d lines\n" % (which, n, len(out)))
print(HDR + "\n".join(out))
