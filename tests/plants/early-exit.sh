#!/usr/bin/env bash
# Run the reference, but stop partway through the program and exit 0.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LUA="$ROOT/.ref/lua-5.4.9/src/lua"
exec "$LUA" -e 'local n=0
debug.sethook(function()
  n = n + 1
  if n >= 40 then
    debug.sethook()
    os.exit(0)
  end
end, "", 1)' "$1"
