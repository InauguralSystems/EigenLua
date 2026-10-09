# Print Lua identifier and dot tokens, one per line.  Strings and comments,
# including long-bracket forms, deliberately produce no tokens.
function long_open(s, p,    q, n) {
  if (substr(s, p, 1) != "[") return -1
  q = p + 1
  while (substr(s, q, 1) == "=") q++
  if (substr(s, q, 1) != "[") return -1
  return q - p - 1
}
function long_close(s, p, n,    q, i) {
  if (substr(s, p, 1) != "]") return 0
  q = p + 1
  for (i = 0; i < n; i++) {
    if (substr(s, q + i, 1) != "=") return 0
  }
  return substr(s, q + n, 1) == "]"
}
{
  s = $0 "\n"
  i = 1
  while (i <= length(s)) {
    if (mode == "long") {
      if (long_close(s, i, eqs)) { mode = ""; i += eqs + 2 }
      else i++
      continue
    }
    if (mode == "quote") {
      c = substr(s, i, 1)
      if (c == "\\") i += 2
      else { if (c == quote) mode = ""; i++ }
      continue
    }
    if (substr(s, i, 2) == "--") {
      n = long_open(s, i + 2)
      if (n >= 0) { mode = "long"; eqs = n; i += n + 4; continue }
      break
    }
    c = substr(s, i, 1)
    if (c == "\"" || c == "'") { mode = "quote"; quote = c; i++; continue }
    n = long_open(s, i)
    if (n >= 0) { mode = "long"; eqs = n; i += n + 2; continue }
    if (c ~ /[A-Za-z_]/) {
      tok = c
      i++
      while (substr(s, i, 1) ~ /[A-Za-z0-9_]/) { tok = tok substr(s, i, 1); i++ }
      print tok
      continue
    }
    if (c == ".") print c
    i++
  }
}
