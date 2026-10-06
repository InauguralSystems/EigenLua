#!/usr/bin/env bash
# Plants for tools/grade.sh. One optional plant name; no args runs every plant.
# A whole-tier plant may use --only. The canary does not: it grades every row.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF="$ROOT/.ref/bin/lua"
COUNT="$ROOT/.ref/bin/lua-count"
GRADE=${GRADE:-$ROOT/tools/grade.sh}
PLANTS="$ROOT/tests/plants"
WORK="$ROOT/.tmp/selftest-$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT
bad=0
ns=$(awk '$1=="include" || $1=="count-unspecified" {c++} END{print c+0}' "$ROOT/corpus/S.manifest")
nd=$(awk 'NF && $1 !~ /^#/{c++} END{print c+0}' "$ROOT/corpus/D.manifest")
plant() {
  local st=OK
  [[ $2 == "$3" ]] || st=WRONG
  [[ $st == OK ]] || bad=1
  printf 'PLANT %s expected=%s got=%s %s\n' "$1" "$2" "$3" "$st"
}
run_at_grade() {
  local g=$1
  shift
  "$g" "$@" >"$WORK/out.txt" 2>"$WORK/err.txt"
  GRADE_RC=$?
}
stage() {
  local dest=$1
  rm -rf "$dest"
  mkdir -p "$dest/tools"
  cp -a "$ROOT/corpus" "$dest/corpus"
  cp -a "$GRADE" "$dest/tools/grade.sh"
  chmod +x "$dest/tools/grade.sh"
  printf '%s\n' "$dest"
}
summary_line() { awk '/^SUMMARY /{s=$0} END{print s}' "$WORK/out.txt"; }
row_bad() { awk -v w="$1" '/^ROW / && $4!=w {c++} END{print c+0}' "$WORK/out.txt"; }
row_n() { awk '/^ROW /{c++} END{print c+0}' "$WORK/out.txt"; }
do_canary() {
  local t0 t1 exp sum got
  t0=$(date +%s)
  run_at_grade "$GRADE" --candidate "$COUNT" --ref "$REF" --tier all
  t1=$(date +%s)
  exp="SUMMARY S=${ns}/${ns} D=${nd}/${nd} fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=$((ns + nd)) rc=0"
  sum=$(summary_line)
  got="$sum rc=$GRADE_RC"
  plant canary "$exp" "$got"
  printf 'canary-runtime-seconds %s rows %s\n' "$((t1 - t0))" "$((ns + nd))" >&2
  if [[ $got != "$exp" ]]; then
    awk '/^ROW / && $4 != "PASS" && $4 != "MATCH"' "$WORK/out.txt" >&2
  fi
}
do_perturb() {
  run_at_grade "$GRADE" --candidate "$PLANTS/perturb.sh" --ref "$REF" --tier D
  local n bad exp got
  n=$(row_n)
  bad=$(row_bad DIVERGE)
  exp="DIVERGE n=$nd rc=1"
  if [[ $GRADE_RC -eq 1 && $n -eq $nd && $bad -eq 0 ]]; then got=$exp; else got="rc=$GRADE_RC n=$n bad=$bad $(summary_line)"; fi
  plant perturb "$exp" "$got"
}
do_silent() {
  local sonly="goto.lua,literals.lua,calls.lua,utf8.lua,events.lua,strings.lua"
  local sn sok=0 dok=0
  sn=$(awk -F, '{print NF}' <<<"$sonly")
  run_at_grade "$GRADE" --candidate "$PLANTS/silent.sh" --ref "$REF" --tier S --only "$sonly"
  local sbad
  sbad=$(awk '/^ROW S / && ($4 != "FAIL" || $0 !~ / rc=0 count=none /) {c++} END{print c+0}' "$WORK/out.txt")
  [[ $GRADE_RC -eq 1 && $(row_n) -eq $sn && $sbad -eq 0 ]] && sok=1
  run_at_grade "$GRADE" --candidate "$PLANTS/silent.sh" --ref "$REF" --tier D
  local dbad
  dbad=$(row_bad DIVERGE)
  [[ $GRADE_RC -eq 1 && $(row_n) -eq $nd && $dbad -eq 0 ]] && dok=1
  local exp="S=FAIL,D=DIVERGE"
  local got=$exp
  [[ $sok -eq 1 && $dok -eq 1 ]] || got="S=$sok D=$dok"
  plant silent "$exp" "$got"
}
do_early_exit() {
  run_at_grade "$GRADE" --candidate "$PLANTS/early-exit.sh" --ref "$REF" --tier S --only goto.lua
  local got
  got=$(awk -v rc="$GRADE_RC" '/^ROW S / { match($0, / count=[0-9]+/); c = substr($0, RSTART + 7, RLENGTH - 7)
      match($0, / ref=[0-9]+/); r = substr($0, RSTART + 5, RLENGTH - 5)
      printf "%s=%s%s ", $3, $4, (c + 0 > 0 && c + 0 < r + 0) ? "-partway" : "-count?" } END { printf "rc=%s", rc }' "$WORK/out.txt")
  plant early-exit "goto.lua=FAIL-partway rc=1" "$got"
}
do_floor_exit() {
  run_at_grade "$GRADE" --candidate "$PLANTS/floor-exit.sh" --ref "$REF" --tier S --only math.lua,nextvar.lua
  plant floor-exit "math.lua=FAIL-progress=same nextvar.lua=FAIL-progress=same rc=1" \
    "$(awk '/^ROW S /{printf "%s=%s-%s ", $3, $4, $NF}' "$WORK/out.txt")rc=$GRADE_RC"
}
do_count_unspec_canary() {
  run_at_grade "$GRADE" --candidate "$COUNT" --ref "$REF" --tier S --only math.lua,nextvar.lua --repeat 20
  plant count-unspec-canary "math.lua=PASS nextvar.lua=PASS rc=0" \
    "$(awk '/^ROW S /{printf "%s=%s ", $3, $4}' "$WORK/out.txt")rc=$GRADE_RC"
}
do_off_by_one() {
  run_at_grade "$GRADE" --candidate "$PLANTS/off-by-one.sh" --ref "$REF" --tier S --only goto.lua,literals.lua
  plant off-by-one "goto.lua=FAIL literals.lua=FAIL rc=1" "$(awk '/^ROW S /{printf "%s=%s ", $3, $4}' "$WORK/out.txt")rc=$GRADE_RC"
}
do_assert_edges() {
  local d="$WORK/edges" r1 r2 n c
  mkdir -p "$d"
  (cd "$PLANTS" && timeout 30 "$REF" assert_edges.lua >"$d/plain.out" 2>/dev/null); r1=$?
  (cd "$PLANTS" && timeout 30 "$COUNT" assert_edges.lua >"$d/count.out" 2>"$d/count.err"); r2=$?
  n=$(sed -n 's/^calls=\([0-9][0-9]*\)$/\1/p' "$d/plain.out")
  c=$(sed -n 's/^EIGENLUA-ASSERTS:\([0-9][0-9]*\)$/\1/p' "$d/count.err")
  local got="rc=$r1/$r2 calls=$n count=$c"
  cmp -s "$d/plain.out" "$d/count.out" || got="$got stdout-differs"
  [[ -n $n && $n -gt 0 && $c == "$n" && $r1 -eq 0 && $r2 -eq 0 ]] && cmp -s "$d/plain.out" "$d/count.out" \
    && got="count=calls stdout=same"
  plant assert-edges "count=calls stdout=same" "$got"
}
do_no_count() {
  run_at_grade "$GRADE" --candidate "$REF" --ref "$REF" --tier S --only goto.lua,literals.lua
  local got
  got="$(awk '/^ROW S /{printf "%s=%s%s ", $3, $4, ($0 ~ / count=none /) ? "-none" : ""}' "$WORK/out.txt")rc=$GRADE_RC"
  plant no-count "goto.lua=FAIL-none literals.lua=FAIL-none rc=1" "$got"
}
do_lying_count() {
  run_at_grade "$GRADE" --candidate "$PLANTS/lying-count.sh" --ref "$REF" --tier S --only goto.lua
  local got
  got=$(awk -v rc="$GRADE_RC" '/^ROW S / { match($0, / count=[0-9]+/); c = substr($0, RSTART + 7, RLENGTH - 7)
      match($0, / ref=[0-9]+/); r = substr($0, RSTART + 5, RLENGTH - 5)
      printf "%s=%s count=%s %s ", $3, $4, (c != "" && c == r ? "ref" : c "/" r), ($0 ~ / progress=differs/) ? "progress=differs" : "progress=?" }
    END { printf "rc=%s", rc }' "$WORK/out.txt")
  plant lying-count "goto.lua=FAIL count=ref progress=differs rc=1" "$got"
}
do_unspecified_D() {
  local dest
  dest=$(stage "$WORK/unspec")
  cat >"$dest/corpus/D/plant_str_pairs.lua" <<'LUA'
-- surface: plant, pairs order over string keys in the hash part
local t = {}
for _, k in ipairs{"alpha", "beta", "gamma", "delta", "eps", "zeta", "eta", "theta"} do t[k] = true end
local s = {}
for k in pairs(t) do s[#s + 1] = k end
print(table.concat(s, " "))
LUA
  echo "plant_str_pairs.lua unspecified-audit: ok" >>"$dest/corpus/D.manifest"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only plant_str_pairs.lua
  harness unspecified-D "is UNSPECIFIED"
}
do_hang() {
  local only="int_one_vs_one.lua,goto_stmt.lua"
  run_at_grade "$GRADE" --candidate "$PLANTS/hang.sh" --ref "$REF" --tier D --only "$only"
  local n sum exp="hang=2 examined=2 rc=1" got
  n=$(awk '/^ROW / && $4=="HANG"{c++} END{print c+0}' "$WORK/out.txt")
  sum=$(summary_line)
  if [[ $GRADE_RC -eq 1 && $n -eq 2 && $sum == *'hang=2'* && $sum == *'examined=2'* && $(row_n) -eq 2 ]]; then
    got=$exp
  else
    got="rc=$GRADE_RC n=$n $sum"
  fi
  plant hang "$exp" "$got"
}
one_row() {  # one_row <plant> <candidate> <VERDICT> <summary field>
  run_at_grade "$GRADE" --candidate "$PLANTS/$2" --ref "$REF" --tier D --only int_one_vs_one.lua
  local n sum got
  n=$(awk -v v="$3" '/^ROW / && $4==v {c++} END{print c+0}' "$WORK/out.txt")
  sum=$(summary_line)
  got="rc=$GRADE_RC n=$n $sum"
  [[ $GRADE_RC -eq 1 && $n -eq 1 && $sum == *" $4=1 "* ]] && got="$3 $4=1 rc=1"
  plant "$1" "$3 $4=1 rc=1" "$got"
}
do_crash() { one_row crash crash.sh CRASH crash; }
do_unsupported() { one_row unsupported unsupported.sh UNSUPPORTED unsupported; }
harness() {
  local name=$1 token=$2 nsum err exp got
  nsum=$(awk '/^SUMMARY /{c++} END{print c+0}' "$WORK/out.txt")
  err=$(tr '\n' ' ' <"$WORK/err.txt")
  exp="exit2:$token"
  if [[ $GRADE_RC -eq 2 && $nsum -eq 0 && $err == *"$token"* ]]; then
    got=$exp
  else
    got="rc=$GRADE_RC summary=$nsum ${err}"
  fi
  plant "$name" "$exp" "$got"
}
do_no_candidate() {
  run_at_grade "$GRADE" --candidate "$PLANTS/missing-candidate" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness no-candidate "not executable"
}
do_wrong_ref() {
  run_at_grade "$GRADE" --candidate "$REF" --ref "$PLANTS/wrong-ref.sh" --tier D --only int_one_vs_one.lua
  harness wrong-ref "not 5.4.9"
}
do_orphan_file() {
  local dest
  dest=$(stage "$WORK/orphan")
  printf '%s\n' '-- surface: orphan not in the manifest' 'print(1)' >"$dest/corpus/D/orphan_extra.lua"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness orphan-file "not in manifest"
}
do_edited_test() {
  local dest f b nb
  dest=$(stage "$WORK/edited")
  f="$dest/corpus/lua-tests/literals.lua"
  b=$(od -An -tu1 -N1 "$f" | tr -d '[:space:]')
  nb=$(( (b + 1) % 256 ))
  printf "\\$(printf '%03o' "$nb")" | dd of="$f" bs=1 count=1 conv=notrunc status=none
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier S --only goto.lua
  harness edited-test "checksum mismatch"
}
do_nondet_D() {
  local dest
  dest=$(stage "$WORK/nondet")
  cat >"$dest/corpus/D/int_one_vs_one.lua" <<'EOF'
-- surface: integers 1 versus 1.0 printing
print(os.time(), os.clock(), tostring({}))
EOF
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness nondet-D "nondeterministic"
}
do_unstable_ref() {
  local d="$WORK/flakyref"
  mkdir -p "$d" && ln -sf "$REF" "$d/lua" && ln -sf "${REF%/*}/lua-seedA" "${REF%/*}/lua-seedB" "$d/"
  ln -sf "$PLANTS/flaky-ref.sh" "$d/lua-count"
  FLAKY_STATE="$WORK/flaky.n" run_at_grade "$GRADE" --candidate "$COUNT" --ref "$d/lua" --tier S --only goto.lua
  plant unstable-ref "goto.lua=UNSTABLE rc=1" "$(awk '/^ROW /{print $3 "=" $4}' "$WORK/out.txt") rc=$GRADE_RC"
}
dispatch() {
  local fn="do_${1//-/_}"
  if declare -F "$fn" >/dev/null; then "$fn"; else printf 'selftest: unknown plant %s\n' "$1" >&2; bad=1; fi
}
if [[ $# -gt 1 ]]; then
  printf 'selftest: pass one plant name or none\n' >&2
  exit 1
fi
if [[ $# -eq 1 ]]; then
  dispatch "$1"
else
  for p in canary perturb silent early-exit floor-exit count-unspec-canary off-by-one assert-edges no-count lying-count unspecified-D unstable-ref hang crash unsupported no-candidate wrong-ref orphan-file edited-test nondet-D; do
    dispatch "$p"
  done
fi
exit "$bad"
