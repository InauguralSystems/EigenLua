#!/usr/bin/env bash
# Run the reference, but stop partway through the program and exit 0: at the
# first line event past line 100, which is after the tier S prelude (line 1).
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LUA="$ROOT/.ref/lua-5.4.9/src/lua"
exec "$LUA" -e 'debug.sethook(function(_, l)
  if l > 100 then debug.sethook() os.exit(0) end
end, "l")' "$1"
