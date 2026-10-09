#!/usr/bin/env bash
# Provision a Codex Cloud task (or any fresh Linux box with git, gcc and sudo)
# the way .devcontainer/Dockerfile provisions CI: build the pinned EigenScript
# from source and install it, then place it where tests/parse_all.sh looks.
# The pin is read from the Dockerfile so the two never drift. The Lua
# reference needs no network: tools/build_ref.sh uses vendor/lua-5.4.9.tar.gz.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=$(sed -n 's/^ARG EIGS_REF=//p' "$ROOT/.devcontainer/Dockerfile")
[[ -n $REF ]] || { echo "cloud_setup: no EIGS_REF in .devcontainer/Dockerfile" >&2; exit 1; }
command -v /usr/bin/time >/dev/null || sudo apt-get install -y -q time >/dev/null
SRC=$(mktemp -d)
git clone -q --depth 1 --branch "$REF" https://github.com/InauguralSystems/EigenScript "$SRC/eigs"
make -s -C "$SRC/eigs" CC=gcc
sudo make -s -C "$SRC/eigs" install PREFIX=/usr/local CC=gcc
mkdir -p "$ROOT/.tmp"
ln -sf /usr/local/bin/eigenscript "$ROOT/.tmp/eigenscript-linux-x86_64"
echo "cloud_setup: run the suite with EIGENLUA_TIMEOUT_SCALE=3 on this box"
echo "cloud_setup: EigenScript $(eigenscript --version) installed (pin $REF)"
