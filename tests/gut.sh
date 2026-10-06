#!/usr/bin/env bash
# Gut-the-guard table. For each row: copy the tree (cp -a, no .git, no .tmp),
# run the plant there from outside (must be OK), replace the guard line with
# the gutted line (the anchor must match exactly one line, which gives
# file:line), run the plant again (must be WRONG); a gutted ref-count.patch
# rebuilds the copy's references first. Optional args: plant names.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRATCH="$ROOT/.tmp/gut"
TABLE=$(cat <<'EOF'
canary	tools/grade.sh	    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]] && (( c >= lo && (hi < 0 || c <= hi) )); then	    if false; then
perturb	tools/grade.sh	  if cmp -s "$exp" "$out" && [[ $rc -eq ${d_exp_rc[$name]} ]]; then	  if true; then
silent	tools/grade.sh	  if [[ $RUN_RC -eq $prc ]] && cmp -s "$WORK/probe.ref" "$WORK/probe.cand"; then	  if true; then
early-exit	tools/grade.sh	    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]] && (( c >= lo && (hi < 0 || c <= hi) )); then	    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ ]]; then
floor-exit	tools/grade.sh	      floor=$(( lo * 10#${s_cu[$name]} / 100 ))	      floor=0
count-unspec-canary	tools/grade.sh	      floor=$(( lo * 10#${s_cu[$name]} / 100 ))	      floor=$hi
no-fraction	tools/grade.sh	    [[ $reason =~ ^floor=0\.([0-9][0-9]?)\ +[^\ ] ]] || die "count-unspecified row has no floor=0.N fraction: $name"	    :
toothless	tools/grade.sh	  if [[ $RUN_RC -eq $prc ]] && cmp -s "$WORK/probe.ref" "$WORK/probe.cand"; then	  if true; then
off-by-one	tools/grade.sh	    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]] && (( c >= lo && (hi < 0 || c <= hi) )); then	    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]]; then
assert-edges	tools/ref-count.patch	+  eigenlua_asserts++;	+  (void)0;
no-count	tools/grade.sh	    if [[ $rc -eq 0 && $c =~ ^[0-9]+$ && $pr == same ]] && (( c >= lo && (hi < 0 || c <= hi) )); then	    if [[ $rc -eq 0 && $pr == same ]]; then
lying-count	tools/grade.sh	    cmp -s "$pre-ref1.o.p" "$pre-cand$k.o.p" || pr="differs($(first_diff "$pre-ref1.o.p" "$pre-cand$k.o.p"))"	    :
unspecified-D	tools/grade.sh	    if ! cmp -s "$pre.1o" "$pre.B"; then	    if false; then
unstable-ref	tools/grade.sh	    if [[ $rcs == *[1-9]* || $prog != same ]] || [[ -z ${s_cu[$name]:-} && $lo -ne $hi ]]; then	    if false; then
hang	tools/grade.sh	  if [[ $rc -eq 124 || $rc -eq 137 ]]; then printf 'HANG\n'; return; fi	  :
crash	tools/grade.sh	  if [[ $rc -ge 128 ]]; then printf 'CRASH\n'; return; fi	  :
unsupported	tools/grade.sh	  if [[ $rc -eq 3 ]] && grep -Eq '^EIGENLUA-UNSUPPORTED:' "$err"; then	  if false; then
no-candidate	tools/grade.sh	if [[ ! -f $CAND || ! -x $CAND ]]; then	if false; then
wrong-ref	tools/grade.sh	  if [[ ! $ver =~ $vre ]]; then	  if false; then
orphan-file	tools/grade.sh	  [[ -n ${d_have[$base]:-} ]] || die "corpus file not in manifest: D/$base"	  :
edited-test	tools/grade.sh	  [[ $got == "${expect[$rel]}" ]] || die "checksum mismatch: $rel"	  :
nondet-D	tools/grade.sh	    if [[ $RC1 -ne $RC2 || $RC1 -ne $RUN_RC ]] || ! cmp -s "$pre.1o" "$pre.2o"; then	    if false; then
EOF
)
copy_tree() {
  local dest=$1 e
  rm -rf "$dest" && mkdir -p "$dest" || return 1
  for e in "$ROOT"/* "$ROOT"/.[!.]*; do
    [[ $(basename "$e") == .tmp ]] && continue
    cp -a "$e" "$dest/" || return 1
  done
  rm -f "$dest/.git"
  [[ ! -e $dest/.git ]]
}
verdict() {  # verdict <tree> <plant>: the plant's OK/WRONG word, or a named failure
  local out rc
  out=$(cd / && timeout 600 "$1/tools/selftest.sh" "$2" 2>/dev/null </dev/null)
  rc=$?
  [[ $rc -eq 124 ]] && { echo HANG; return; }
  out=$(grep -E "^PLANT $2 " <<<"$out")
  [[ $(grep -c . <<<"$out") -eq 1 ]] || { echo "NO-ROW(rc=$rc)"; return; }
  echo "${out##* }"
}
plants=$(sed -n 's/^  for p in \(.*\); do$/\1/p' "$ROOT/tools/selftest.sh" | tr ' ' '\n' | sort -u)
listed=$(cut -f1 <<<"$TABLE" | sort -u)
[[ -n $plants && $plants == "$listed" ]] || { echo "GUT table plants differ from selftest plants"; diff <(echo "$plants") <(echo "$listed"); exit 2; }
rows=0 bad=0
while IFS=$'\t' read -r plant file anchor gutted; do
  [[ $# -eq 0 || " $* " == *" $plant "* ]] || continue
  rows=$((rows + 1))
  dest="$SCRATCH/$plant-$rows"
  copy_tree "$dest" || { echo "GUT $plant copy failed"; bad=1; continue; }
  hits=$(A=$anchor awk '$0 == ENVIRON["A"] { printf "%s%d", (n++ ? "," : ""), NR }' "$dest/$file")
  if [[ ! $hits =~ ^[0-9]+$ ]]; then echo "GUT $plant anchor matched lines [$hits] in $file"; bad=1; continue; fi
  intact=$(verdict "$dest" "$plant")
  G=$gutted awk -v n="$hits" 'NR == n { print ENVIRON["G"]; next } { print }' "$dest/$file" >"$dest/$file.g" \
    && chmod --reference="$dest/$file" "$dest/$file.g" && mv "$dest/$file.g" "$dest/$file"
  cmp -s "$ROOT/$file" "$dest/$file" && { echo "GUT $plant edit did not change $file"; bad=1; continue; }
  if [[ $file == tools/ref-count.patch ]]; then (cd / && timeout 900 "$dest/tools/build_ref.sh" >/dev/null 2>&1) || { echo "GUT $plant rebuild failed"; bad=1; continue; }; fi
  gut=$(verdict "$dest" "$plant")
  st=ok
  [[ $intact == OK && $gut == WRONG ]] || { st=BAD; bad=1; }
  printf 'GUT %s | %s:%s | intact=%s | gutted=%s | %s\n' "$plant" "$file" "$hits" "$intact" "$gut" "$st"
  rm -rf "$dest"
done <<<"$TABLE"
[[ $rows -gt 0 ]] || { echo "GUT examined 0 rows"; exit 2; }
echo "GUT-SUMMARY rows=$rows bad=$bad"
exit "$bad"
