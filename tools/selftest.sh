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
nd=$(awk 'NF && $1 !~ /^#/ && $1 != "operators:" {c++} END{print c+0}' "$ROOT/corpus/D.manifest")
plant() {
  local st=OK
  [[ $2 == "$3" ]] || { st=WRONG; bad=1; }
  printf 'PLANT %s expected=%s got=%s %s\n' "$1" "$2" "$3" "$st"
}
run_at_grade() {
  local g=$1
  shift
  "$g" "$@" >"$WORK/out.txt" 2>"$WORK/err.txt"
  GRADE_RC=$?
}
stage() {
  rm -rf "$1" && mkdir -p "$1/tools" && cp -a "$ROOT/corpus" "$1/corpus" && cp -a "$GRADE" "$1/tools/grade.sh"
  cp -a "$ROOT/tools/lua_code_tokens.awk" "$1/tools/lua_code_tokens.awk"
  chmod +x "$1/tools/grade.sh"
  printf '%s\n' "$1"
}
summary_line() { awk '/^SUMMARY /{s=$0} END{print s}' "$WORK/out.txt"; }
row_bad() { awk -v w="$1" '/^ROW / && $4!=w {c++} END{print c+0}' "$WORK/out.txt"; }
row_n() { awk '/^ROW /{c++} END{print c+0}' "$WORK/out.txt"; }
do_canary() {
  local exp="SUMMARY S=${ns}/${ns} D=${nd}/${nd} fail=0 diverge=0 hang=0 crash=0 unsupported=0 examined=$((ns + nd)) assert=trusted rc=0"
  run_at_grade "$GRADE" --candidate "$COUNT" --ref "$REF" --tier all
  plant canary "$exp" "$(summary_line) rc=$GRADE_RC"
  awk '/^ROW / && $4 != "PASS" && $4 != "MATCH"' "$WORK/out.txt" >&2
}
do_perturb() {
  run_at_grade "$GRADE" --candidate "$PLANTS/perturb.sh" --ref "$REF" --tier D
  plant perturb "DIVERGE n=$nd bad=0 rc=1" "DIVERGE n=$(row_n) bad=$(row_bad DIVERGE) rc=$GRADE_RC"
}
do_hang() {
  run_at_grade "$GRADE" --candidate "$PLANTS/hang.sh" --ref "$REF" --tier D --only int_one_vs_one.lua,goto_stmt.lua
  plant hang "HANG=2 rows=2 hang=2 examined=2 rc=1" "HANG=$(awk '/^ROW / && $4=="HANG"' "$WORK/out.txt" | grep -c .) rows=$(row_n) $(summary_line | grep -o 'hang=[0-9]*') $(summary_line | grep -o 'examined=[0-9]*') rc=$GRADE_RC"
}
do_ops_drop() {
  local dest
  dest=$(stage "$WORK/opsdrop")
  sed -i '/^  {"<<", function/d' "$dest/corpus/D/ops_matrix.lua"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness ops-drop "operator table"
}
do_silent() {
  local sonly="goto.lua,literals.lua,calls.lua,utf8.lua,events.lua,strings.lua" sok=0 dok=0
  run_at_grade "$GRADE" --candidate "$PLANTS/silent.sh" --ref "$REF" --tier S --only "$sonly"
  [[ $GRADE_RC -eq 1 && $(row_n) -eq 6 && $(awk '/^ROW S / && ($4 != "FAIL" || $5 != "assert-untrusted")' "$WORK/out.txt") == '' ]] && sok=1
  run_at_grade "$GRADE" --candidate "$PLANTS/silent.sh" --ref "$REF" --tier D
  [[ $GRADE_RC -eq 1 && $(row_n) -eq $nd && $(row_bad DIVERGE) -eq 0 ]] && dok=1
  plant silent "S=1 D=1" "S=$sok D=$dok"
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
do_toothless() {
  run_at_grade "$GRADE" --candidate "${REF%/*}/lua-toothless" --ref "$REF" --tier S
  local untr
  untr=$(awk '/^ROW S / && $4 == "FAIL" && $5 == "assert-untrusted" {c++} END{print c+0}' "$WORK/out.txt")
  plant toothless "S=0/$ns untrusted=$ns assert=untrusted rc=1" \
    "$(summary_line | grep -o 'S=[0-9]*/[0-9]*') untrusted=$untr $(summary_line | grep -o 'assert=[a-z/]*') rc=$GRADE_RC"
}
do_callsite_toothless() {
  run_at_grade "$GRADE" --candidate "$PLANTS/callsite-toothless.sh" --ref "$REF" --tier S
  local n
  n=$(awk '/^ROW S / && $4 == "FAIL" && $5 == "assert-untrusted(control)" {c++} END{print c+0}' "$WORK/out.txt")
  plant callsite-toothless "S=0/$ns control=$ns assert=trusted rc=1" \
    "$(summary_line | grep -o 'S=[0-9]*/[0-9]*') control=$n $(summary_line | grep -o 'assert=[a-z/]*') rc=$GRADE_RC"
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
  local nsum err got
  nsum=$(grep -c '^SUMMARY ' "$WORK/out.txt")
  err=$(tr '\n' ' ' <"$WORK/err.txt")
  got="rc=$GRADE_RC summary=$nsum ${err}"
  [[ $GRADE_RC -eq 2 && $nsum -eq 0 && $err == *"$2"* ]] && got="exit2:$2"
  plant "$1" "exit2:$2" "$got"
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
frac_plant() {  # <plant> <replacement for "floor=0.90 "> <harness token>
  local dest
  dest=$(stage "$WORK/$1")
  sed -i "s/^count-unspecified nextvar.lua floor=0\.90 /count-unspecified nextvar.lua $2/" "$dest/corpus/S.manifest"
  run_at_grade "$dest/tools/grade.sh" --candidate "$COUNT" --ref "$REF" --tier S --only goto.lua
  harness "$1" "$3"
}
do_no_fraction() { frac_plant no-fraction "" "has no floor=0.N fraction"; }
do_floor_zero() { frac_plant floor-zero "floor=0.00 " "must be in (0,1)"; }
do_rc99() {
  run_at_grade "$GRADE" --candidate "$PLANTS/rc99.sh" --ref "$REF" --tier all --only int_one_vs_one.lua,goto.lua
  plant rc99 "goto.lua=FAIL int_one_vs_one.lua=DIVERGE summary=1 rc=1" \
    "$(awk '/^ROW /{printf "%s=%s ", $3, $4}' "$WORK/out.txt")summary=$(grep -c '^SUMMARY' "$WORK/out.txt") rc=$GRADE_RC"
}
do_unspecified_rc() {
  local dest
  dest=$(stage "$WORK/unsprc")
  printf '%s\n' '-- surface: plant, exit status from pairs order over string keys' 'local t = {}' \
    'for _, k in ipairs{"alpha", "beta", "gamma", "delta", "eps", "zeta", "eta", "theta"} do t[k] = true end' \
    'print("same stdout")' 'os.exit((next(t) == "alpha") and 3 or 4)' >"$dest/corpus/D/plant_rc.lua"
  echo "plant_rc.lua unspecified-audit: ok" >>"$dest/corpus/D.manifest"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only plant_rc.lua
  harness unspecified-rc "is UNSPECIFIED"
}
do_dup_manifest() {
  local dest
  dest=$(stage "$WORK/dupman")
  grep -m 1 'unspecified-audit: ok$' "$dest/corpus/D.manifest" >>"$dest/corpus/D.manifest"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness dup-manifest "duplicate D manifest line"
}
do_builtin_missing() {
  local dest
  dest=$(stage "$WORK/bimiss")
  sed -i '/^string\.rep /d' "$dest/corpus/builtins.inventory"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness builtin-missing "missing [string.rep ]"
}
do_builtin_uncited() {
  local dest
  dest=$(stage "$WORK/biunc")
  sed -i 's/^string\.rep .*/string.rep break_outside_loop.lua/' "$dest/corpus/builtins.inventory"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness builtin-uncited "does not mention string.rep"
}
do_builtin_comment_citation() {
  local dest
  dest=$(stage "$WORK/bicomment")
  printf '\n-- string.rep is cited only by this trailing comment\n' >>"$dest/corpus/D/break_outside_loop.lua"
  sed -i 's/^string\.rep .*/string.rep break_outside_loop.lua/' "$dest/corpus/builtins.inventory"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness builtin-comment-citation "does not mention string.rep in code tokens"
}
do_builtin_string_citation() {
  local dest
  dest=$(stage "$WORK/bistring")
  printf '\nlocal builtin_citation = "string.rep"\n' >>"$dest/corpus/D/break_outside_loop.lua"
  sed -i 's/^string\.rep .*/string.rep break_outside_loop.lua/' "$dest/corpus/builtins.inventory"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness builtin-string-citation "does not mention string.rep in code tokens"
}
do_compat_ref() {
  local c p
  "$ROOT/tools/build_ref.sh" --check-not-compat "${REF%/*}/lua-compat" 2>/dev/null; c=$?
  "$ROOT/tools/build_ref.sh" --check-not-compat "$REF" 2>/dev/null; p=$?
  plant compat-ref "compat=1 pristine=0" "compat=$c pristine=$p"
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
  for p in canary perturb silent early-exit floor-exit count-unspec-canary no-fraction floor-zero toothless callsite-toothless off-by-one assert-edges no-count lying-count unspecified-D unspecified-rc ops-drop rc99 compat-ref unstable-ref hang crash unsupported no-candidate wrong-ref orphan-file edited-test nondet-D dup-manifest builtin-missing builtin-uncited builtin-comment-citation builtin-string-citation; do
    dispatch "$p"
  done
fi
exit "$bad"
