#!/usr/bin/env bash
# The counting reference, stopped partway through the program with exit 0: at
# the first line event past line 100. The atexit hook still writes the count.
set -u
ROOT=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
exec "$ROOT/.ref/bin/lua-count" -e 'debug.sethook(function(_, l)
  if l > 100 then debug.sethook() os.exit(0) end
end, "l")' "$1"
