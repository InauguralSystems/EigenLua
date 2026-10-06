#!/usr/bin/env bash
# Run the reference, then change one stdout byte.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LUA="$ROOT/.ref/bin/lua"
mkdir -p "$ROOT/.tmp"
out="$ROOT/.tmp/perturb-$$.out"
trap 'rm -f "$out"' EXIT
"$LUA" "$1" >"$out"
rc=$?
if [[ ! -s $out ]]; then
  printf 'X\n'
  exit "$rc"
fi
b=$(od -An -tu1 -N1 "$out" | tr -d '[:space:]')
nb=$(( (b + 1) % 256 ))
printf "\\$(printf '%03o' "$nb")" | dd of="$out" bs=1 count=1 conv=notrunc status=none
cat "$out"
exit "$rc"
