#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=${REF:-"$ROOT/.ref/bin/lua"}
CANDIDATE=${CANDIDATE:-"$ROOT/bin/eigenlua"}
rows='number_arith.lua:1428 number_arith2.lua:142 number_text.lua:555 number_keys.lua:30 nil_number.lua:31 number_kinds.lua:60'
work=$(mktemp -d "${TMPDIR:-/tmp}/eigenlua-numlines.XXXXXX") || exit 2
trap 'rm -rf "$work"' EXIT HUP INT TERM
compare() {
  name=$1 expected=$2 ref=$3 cand=$4
  rn=$(wc -l <"$ref" | tr -d ' '); cn=$(wc -l <"$cand" | tr -d ' ')
  if [ "$rn" -ne "$expected" ] || [ "$cn" -ne "$expected" ]; then
    printf 'ERROR %s expected=%s ref=%s candidate=%s\n' "$name" "$expected" "$rn" "$cn" >&2; return 2
  fi
  awk 'NR==FNR { r[NR]=$0; next } $0 != r[FNR] { n++; d[n]=r[FNR] " | " $0 } END { printf "ROW %s lines=%d differ=%d\n", NAME, FNR, n+0; for(i=1;i<=n;i++) print d[i]; exit n>0 }' NAME="$name" "$ref" "$cand"
}
if [ "${1:-}" = --selftest ]; then
  printf 'same\nref\n' >"$work/ref"; printf 'same\ncandidate\n' >"$work/cand"
  out=$(compare planted 2 "$work/ref" "$work/cand"); rc=$?
  [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'differ=1' && printf '%s\n' "$out" | grep -q 'ref | candidate' || exit 1
  printf 'same\n' >"$work/short"
  compare missing 2 "$work/ref" "$work/short" >/dev/null 2>&1; [ $? -eq 2 ] || exit 1
  echo 'PASS numlines planted difference and missing-line error'; exit 0
fi
total=0; bad=0
for item in $rows; do
 name=${item%:*}; expected=${item#*:}
 "$REF" "$ROOT/corpus/D/$name" >"$work/$name.ref" 2>"$work/$name.ref.err"; rr=$?
 "$CANDIDATE" "$ROOT/corpus/D/$name" >"$work/$name.cand" 2>"$work/$name.cand.err"; cr=$?
 compare "$name" "$expected" "$work/$name.ref" "$work/$name.cand"; rc=$?
 [ "$rc" -eq 2 ] && bad=2
 n=$(awk 'NR==FNR{r[NR]=$0;next}$0!=r[FNR]{n++}END{print n+0}' "$work/$name.ref" "$work/$name.cand")
 total=$((total+n)); [ "$rr" -eq 0 ] || bad=2; [ "$cr" -eq 0 ] || bad=2
done
printf 'TOTAL differ=%d\n' "$total"
exit "$bad"
