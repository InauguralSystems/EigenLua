#!/usr/bin/env bash
# Build the PUC-Rio Lua 5.4.9 references into .ref/bin/ from the verified
# tarball. Refuse a bad tarball.
#   lua        pristine: tier D, and the reference arm's stdout/rc
#   lua-count  + tools/ref-count.patch: luaB_assert counts its calls, and an
#              atexit hook writes EIGENLUA-ASSERTS:<n> to stderr (tier S)
#   lua-seedA  pristine with luai_makeseed fixed to 0x12345u  } tier D layout
#   lua-seedB  pristine with luai_makeseed fixed to 0x6789Bu  } check
#   lua-toothless  TEST-ONLY: lua-count whose assert never raises (plant)
# The builds are cached under a key of the tarball, patch and script hashes.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF="$ROOT/.ref"
URL="https://www.lua.org/ftp/lua-5.4.9.tar.gz"
SHA="2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6"
TAR="lua-5.4.9.tar.gz"
PATCH="$ROOT/tools/ref-count.patch"
BIN="$REF/bin"

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

# build <name> <MYCFLAGS> [patch|toothless]. 5.4.9's `linux` target does not
# link readline. lstate.c defines luai_makeseed only `#if !defined(...)`, so
# -D replaces the time-and-address seed entirely. lua-toothless is TEST-ONLY
# (plant `toothless`): lua-count whose assert never raises.
build() {
  local name=$1 cflags=$2 d="$REF/build-$1" src
  rm -rf "$d" && mkdir -p "$d"
  tar -xzf "$TAR" -C "$d"
  src="$d/lua-5.4.9/src/lbaselib.c"
  if [[ -n ${3:-} ]]; then patch -s -p1 -d "$d/lua-5.4.9" <"$PATCH"; fi
  if [[ ${3:-} == toothless ]]; then
    sed -i 's|^  if (l_likely(lua_toboolean(L, 1)))  /\* condition is true? \*/$|  if (1)  /* TEST-ONLY: assert never raises */|' "$src"
    grep -q 'TEST-ONLY: assert never raises' "$src"
  fi
  make -s -C "$d/lua-5.4.9" linux MYCFLAGS="$cflags" >/dev/null
  cp "$d/lua-5.4.9/src/lua" "$BIN/$name.new"
  mv "$BIN/$name.new" "$BIN/$name"
  rm -rf "$d"
}
names="lua lua-count lua-seedA lua-seedB lua-toothless"
have=1
for n in $names; do [[ -x $BIN/$n ]] || have=0; done
if [[ $have -eq 0 || $(cat "$BIN/.key" 2>/dev/null) != "$key" ]]; then
  rm -f "$BIN/.key"
  build lua ""
  build lua-count "" patch
  build lua-seedA "'-Dluai_makeseed(L)=0x12345u'"
  build lua-seedB "'-Dluai_makeseed(L)=0x6789Bu'"
  build lua-toothless "" toothless
  echo "$key" >"$BIN/.key"
fi
for n in $names; do printf '%s: ' "$n"; "$BIN/$n" -v; done
