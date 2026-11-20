import random, sys
MAX = 2**63-1; MIN = -2**63
def lit(v):
    if v == MIN: return "(-9223372036854775807-1)"
    if v < 0: return "(%d)" % v
    return "%d" % v
bounds = [MAX, MIN, 2**31, 2**32, 2**53, 2**62]
ops = ["+", "-", "*", "//", "%"]
pairs = []
for B in bounds:
    for v in (B-1, B, B+1):
        if not (MIN <= v <= MAX): continue
        for s in (1, -1, 2, 3, v):
            for op in ops: pairs.append((v, op, s))
        pairs.append((v, "u-", None))
seen = set(); P = []
for p in pairs:
    if p in seen: continue
    seen.add(p); P.append(p)
R = random.Random(20261119); rnd = []
for _ in range(60):
    k = R.choice(["any", "near"])
    if k == "any": a = R.randint(MIN, MAX); b = R.randint(MIN, MAX)
    else:
        a = R.choice(bounds) + R.randint(-3, 3); b = R.randint(-5, 5) or 7
        a = max(MIN, min(MAX, a))
    op = R.choice(ops + ["u-"]); rnd.append((a, op, b if op != "u-" else None))
out = ["-- surface: non-stopping int64 arithmetic boundaries", "local function show(tag, ok, v) if ok then print(tag, math.type(v), v) else print(tag, 'ERR', v) end end"]
def expr(a, op, b, A, B):
    if op == "u-": return "-%s" % A
    return "%s %s %s" % (A, op, B)
n = 0
for group, L in (("bnd", P), ("rnd", rnd)):
    for (a, op, b) in L:
        n += 1; tag = "%s%03d" % (group, n)
        el = expr(a, op, b, lit(a), lit(b) if b is not None else None)
        ev = expr(a, op, b, "x", "y")
        out.append("show('%s L %s', pcall(function() return %s end))" % (tag, el, el))
        out.append("show('%s V', pcall(function(x, y) return %s end, %s, %s))" % (tag, ev, lit(a), lit(b) if b is not None else "nil"))
        out.append("show('%s D', pcall(function() return load('return %s')() end))" % (tag, el))
sys.stderr.write("expressions: %d (x3 ways = %d lines)\n" % (n, 3*n))
print("\n".join(out))
