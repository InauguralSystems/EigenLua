#!/usr/bin/env bash
# Build the PUC-Rio Lua 5.4.9 reference under .ref/. Refuse a bad tarball.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF="$ROOT/.ref"
URL="https://www.lua.org/ftp/lua-5.4.9.tar.gz"
SHA="2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6"
TAR="lua-5.4.9.tar.gz"

mkdir -p "$REF"
cd "$REF"

if [[ ! -f $TAR ]]; then
  tmp="$TAR.partial"
  rm -f "$tmp"
  curl -fsSL -o "$tmp" "$URL"
  mv "$tmp" "$TAR"
fi

got=$(sha256sum "$TAR" | awk '{print $1}')
if [[ "$got" != "$SHA" ]]; then
  printf 'SHA-256 mismatch for %s\nexpected %s\ngot      %s\n' "$TAR" "$SHA" "$got" >&2
  rm -f "$TAR"
  exit 1
fi

if [[ ! -x lua-5.4.9/src/lua ]]; then
  if [[ ! -d lua-5.4.9 ]]; then
    tar -xzf "$TAR"
  fi
  # 5.4.9's `linux` target is linux-noreadline (no -lreadline). It builds
  # clean on this box without readline headers.
  make -C lua-5.4.9 linux
fi

exec ./lua-5.4.9/src/lua -v
