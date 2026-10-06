#!/usr/bin/env bash
# Build the PUC-Rio Lua 5.4.9 references into .ref/bin/ from the verified
# tarball. Refuse a bad tarball. Every binary is built WITHOUT the
# -DLUA_COMPAT_5_3 that 5.4.9's src/Makefile hard-codes, so the reference is
# Lua 5.4 as the manual defines it (no math.pow, no __lt standing in for
# __le); each is checked for that after the build, and a failure stops it.
#   lua        pristine: tier D, and the reference arm's stdout/rc
#   lua-count  + tools/ref-count.patch: luaB_assert counts its calls, and an
#              atexit hook writes EIGENLUA-ASSERTS:<n> to stderr (tier S)
#   lua-seedA  pristine with luai_makeseed fixed to 0x12345u  } tier D layout
#   lua-seedB  pristine with luai_makeseed fixed to 0x6789Bu  } check
#   lua-toothless  TEST-ONLY: lua-count whose assert never raises (plant)
#   lua-compat     TEST-ONLY: pristine WITH LUA_COMPAT_5_3 (plant compat-ref)
# The builds are cached under a key of the tarball, patch and script hashes.
# tools/build_ref.sh --check-not-compat <bin>: the check alone (exit 1 = compat).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF="$ROOT/.ref"
URL="https://www.lua.org/ftp/lua-5.4.9.tar.gz"
SHA="2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6"
TAR="lua-5.4.9.tar.gz"
PATCH="$ROOT/tools/ref-count.patch"
BIN="$REF/bin"

# The 5.4 behaviour the compat flag changes: math.pow absent, and `<=` on
# values with only __lt raises. A binary that fails either is not 5.4.
not_compat() {
  "$1" -e 'local a = setmetatable({}, {__lt = function() return true end})
    if math.pow ~= nil or pcall(function() return a <= a end) then os.exit(1) end' >/dev/null 2>&1
}
if [[ ${1:-} == --check-not-compat ]]; then
  not_compat "$2" || { echo "COMPAT: $2 has LUA_COMPAT_5_3 behaviour" >&2; exit 1; }
  exit 0
fi

mkdir -p "$REF" "$BIN"
cd "$REF"
if [[ ! -f $TAR ]]; then
  rm -f "$TAR.partial"
  curl -fsSL -o "$TAR.partial" "$URL"
  mv "$TAR.partial" "$TAR"
fi
got=$(sha256sum "$TAR" | awk '{print $1}')
if [[ "$got" != "$SHA" ]]; then
  printf 'SHA-256 mismatch for %s\nexpected %s\ngot      %s\n' "$TAR" "$SHA" "$got" >&2
  rm -f "$TAR"
  exit 1
fi
key=$(cat "$TAR" "$PATCH" "$ROOT/tools/build_ref.sh" | sha256sum | awk '{print $1}')

# build <name> <MYCFLAGS> [patch|toothless|compat]. 5.4.9's `linux` target
# does not link readline. lstate.c defines luai_makeseed only `#if
# !defined(...)`, so -D replaces the time-and-address seed entirely.
build() {
  local name=$1 cflags=$2 d="$REF/build-$1" src mk
  rm -rf "$d" && mkdir -p "$d"
  tar -xzf "$TAR" -C "$d"
  src="$d/lua-5.4.9/src/lbaselib.c" mk="$d/lua-5.4.9/src/Makefile"
  if [[ ${3:-} != compat ]]; then
    sed -i 's/^CFLAGS= -O2 -Wall -Wextra -DLUA_COMPAT_5_3 /CFLAGS= -O2 -Wall -Wextra /' "$mk"
    ! grep -q 'LUA_COMPAT_5_3' "$mk"
  fi
  if [[ ${3:-} == patch || ${3:-} == toothless ]]; then patch -s -p1 -d "$d/lua-5.4.9" <"$PATCH"; fi
  if [[ ${3:-} == toothless ]]; then
    sed -i 's|^  if (l_likely(lua_toboolean(L, 1)))  /\* condition is true? \*/$|  if (1)  /* TEST-ONLY: assert never raises */|' "$src"
    grep -q 'TEST-ONLY: assert never raises' "$src"
  fi
  make -s -C "$d/lua-5.4.9" linux MYCFLAGS="$cflags" >/dev/null
  if [[ ${3:-} != compat ]]; then
    not_compat "$d/lua-5.4.9/src/lua" || { echo "COMPAT: built $name has LUA_COMPAT_5_3 behaviour" >&2; exit 1; }
  fi
  cp "$d/lua-5.4.9/src/lua" "$BIN/$name.new"
  mv "$BIN/$name.new" "$BIN/$name"
  rm -rf "$d"
}
names="lua lua-count lua-seedA lua-seedB lua-toothless lua-compat"
have=1
for n in $names; do [[ -x $BIN/$n ]] || have=0; done
if [[ $have -eq 0 || $(cat "$BIN/.key" 2>/dev/null) != "$key" ]]; then
  rm -f "$BIN/.key"
  build lua ""
  build lua-count "" patch
  build lua-seedA "'-Dluai_makeseed(L)=0x12345u'"
  build lua-seedB "'-Dluai_makeseed(L)=0x6789Bu'"
  build lua-toothless "" toothless
  build lua-compat "" compat
  echo "$key" >"$BIN/.key"
fi
for n in $names; do printf '%s: ' "$n"; "$BIN/$n" -v; done
