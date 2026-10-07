#!/usr/bin/env bash
# Sub-oracle for the front end's grammar: parse every corpus/D/*.lua and every
# graded (include / count-unspecified) row of corpus/S.manifest with
# src/compile.eigs --parse-only. A file passes when it parses (exit 0). A file
# that fails must print a located message ("<file>:<line>:" or
# EIGENLUA-UNSUPPORTED ... at <file>:<line>) or it is reported as UNLOCATED.
# The population is derived from the files on disk and the manifest, and
# examined == expected (every D program, at least 47, + 23 S) > 0 is asserted. Prints parsed=<k>/<n>;
# exit 0 iff k == n.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ES=${EIGENSCRIPT:-$(command -v eigenscript || true)}
[[ -n $ES && -x $ES ]] || { echo "HARNESS: no EigenScript VM (set EIGENSCRIPT or put eigenscript on PATH)"; exit 2; }
files=()
for f in "$ROOT"/corpus/D/*.lua; do files+=("$f"); done
nd=${#files[@]}
while read -r status name _; do
  [[ $status == include || $status == count-unspecified ]] || continue
  files+=("$ROOT/corpus/lua-tests/$name")
done <"$ROOT/corpus/S.manifest"
ns=$(( ${#files[@]} - nd ))
[[ $nd -ge 47 && $ns -eq 23 ]] || { echo "HARNESS: population D=$nd S=$ns, want >= 47 and 23"; exit 2; }
k=0 n=0
for f in "${files[@]}"; do
  n=$((n + 1))
  out=$(cd "$(dirname "$f")" && timeout 60 "$ES" "$ROOT/src/compile.eigs" --parse-only "$(basename "$f")" 2>&1)
  rc=$?
  rel=${f#"$ROOT/"}
  if [[ $rc -eq 0 ]]; then
    k=$((k + 1))
  elif grep -qE "(^lua: [^:]+:[0-9]+: |^EIGENLUA-UNSUPPORTED: .* at [^:]+:[0-9]+$)" <<<"$out"; then
    echo "FAIL $rel rc=$rc ${out%%$'\n'*}"
  else
    echo "UNLOCATED $rel rc=$rc ${out%%$'\n'*}"
  fi
done
[[ $n -eq $((nd + ns)) && $n -gt 0 ]] || { echo "HARNESS: examined $n of $((nd + ns))"; exit 2; }
echo "parsed=$k/$n"
[[ $k -eq $n ]]
