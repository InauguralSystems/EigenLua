#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=${REF:-"$ROOT/.ref/bin/lua"}
CANDIDATE=${CANDIDATE:-"$ROOT/bin/eigenlua"}
rows='number_arith.lua:1428 number_arith2.lua:142 number_text.lua:555 number_keys.lua:30 nil_number.lua:31 number_kinds.lua:60 review2-arith.lua:624 review2-text.lua:894 review2-keys.lua:516 review2-nil.lua:597 review2-kinds.lua:633 review2-mathinf.lua:33 review2-fdiv.lua:28 review2-forlim.lua:17'
work=$(mktemp -d "${TMPDIR:-/tmp}/eigenlua-numlines.XXXXXX") || exit 2
trap 'rm -rf "$work"' EXIT HUP INT TERM
compare() {
  name=$1 expected=$2 ref=$3 cand=$4
  rn=$(wc -l <"$ref" | tr -d ' '); cn=$(wc -l <"$cand" | tr -d ' ')
  if [ "$rn" -ne "$expected" ]; then
    printf 'ERROR %s expected=%s ref=%s candidate=%s\n' "$name" "$expected" "$rn" "$cn" >&2; return 2
  fi
  awk 'NR==FNR { r[NR]=$0; nr=NR; next } $0 != r[FNR] { n++; d[n]=r[FNR] " | " $0 } END { incomplete=nr-FNR; if(incomplete<0) incomplete=0; n+=incomplete; printf "ROW %s lines=%d differ=%d incomplete=%d\n", NAME, nr, n+0, incomplete; for(i=1;i<=n-incomplete;i++) print d[i]; exit n>0 }' NAME="$name" "$ref" "$cand"
}
exclude_unspecified() {
  name=$1 file=$2
  # Lua leaves iterator identity and table borders with holes open. These
  # review expressions are outside the differential population.
  if [ "$name" = review2-nil.lua ]; then
    awk '$1 !~ /^N0(39|40|53)$/' "$file" >"$file.specified"
    mv "$file.specified" "$file"
  elif [ "$name" = review2-mathinf.lua ]; then
    awk '$1 != "math.abs(0/0)"' "$file" >"$file.specified"
    mv "$file.specified" "$file"
  elif [ "$name" = review2-fdiv.lua ]; then
    awk '$1 != "-(0/0)//1"' "$file" >"$file.specified"
    mv "$file.specified" "$file"
  fi
}
if [ "${1:-}" = --selftest ]; then
  printf 'same\nref\n' >"$work/ref"; printf 'same\ncandidate\n' >"$work/cand"
  out=$(compare planted 2 "$work/ref" "$work/cand"); rc=$?
  [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'differ=1' && printf '%s\n' "$out" | grep -q 'ref | candidate' || exit 1
  printf 'same\nref\nthird\n' >"$work/three-ref"; printf 'same\nref\n' >"$work/short"
  out=$(compare missing 3 "$work/three-ref" "$work/short"); rc=$?
  [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'differ=1 incomplete=1' || exit 1
  echo 'PASS numlines planted difference and missing-line accounting'; exit 0
fi
total=0; incomplete=0; bad=0
for item in $rows; do
 name=${item%:*}; expected=${item#*:}
 case $name in
   review2-arith.lua|review2-text.lua|review2-keys.lua|review2-nil.lua|review2-kinds.lua)
     class=${name#review2-}; class=${class%.lua}; python3 "$ROOT/tools/review2/gen.py" "$class" >"$work/$name.input" 2>"$work/$name.gen.err" ;;
   review2-*) cp "$ROOT/tools/review2/${name#review2-}" "$work/$name.input" ;;
   *) cp "$ROOT/corpus/D/$name" "$work/$name.input" ;;
 esac
 "$REF" "$work/$name.input" >"$work/$name.ref" 2>"$work/$name.ref.err"; rr=$?
 "$CANDIDATE" "$work/$name.input" >"$work/$name.cand" 2>"$work/$name.cand.err"; cr=$?
 exclude_unspecified "$name" "$work/$name.ref"
 exclude_unspecified "$name" "$work/$name.cand"
 compare "$name" "$expected" "$work/$name.ref" "$work/$name.cand"; rc=$?
 [ "$rc" -eq 2 ] && bad=2
 read n miss <<EOF
$(awk 'NR==FNR{r[NR]=$0;nr=NR;next}$0!=r[FNR]{n++}END{m=nr-FNR;if(m<0)m=0;print n+m,m}' "$work/$name.ref" "$work/$name.cand")
EOF
 total=$((total+n)); incomplete=$((incomplete+miss)); [ "$rr" -eq 0 ] || bad=2; [ "$cr" -eq 0 ] || bad=2
done
printf 'TOTAL differ=%d incomplete=%d\n' "$total" "$incomplete"
exit "$bad"
