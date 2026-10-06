#!/usr/bin/env bash
# Plants for tools/grade.sh. One optional plant name; no args runs every plant.
# A whole-tier plant may use --only. The canary does not: it grades every row.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF="$ROOT/.ref/lua-5.4.9/src/lua"
GRADE=${GRADE:-$ROOT/tools/grade.sh}
PLANTS="$ROOT/tests/plants"
WORK="$ROOT/.tmp/selftest-$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT
bad=0
ns=$(awk '$1=="include" || $1=="band" {c++} END{print c+0}' "$ROOT/corpus/S.manifest")
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
  cp -a "$ROOT/tools/s_shim.lua" "$dest/tools/s_shim.lua"
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
  run_at_grade "$GRADE" --candidate "$REF" --ref "$REF" --tier all
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
  sbad=$(awk '/^ROW S / && ($4 != "FAIL" || $0 !~ /cand=none rc=0/) {c++} END{print c+0}' "$WORK/out.txt")
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
do_early() {
  run_at_grade "$GRADE" --candidate "$PLANTS/early-exit.sh" --ref "$REF" --tier S --only goto.lua,nextvar.lua
  local exp="goto.lua=FAIL nextvar.lua=FAIL-band rc=1" got
  got=$(awk -v rc="$GRADE_RC" '/^ROW S / {
      v = $3 "=" $4; if ($0 ~ / band=\[/) v = v "-band"
      if (!match($0, / (ref|band)=\[?[0-9]+/)) v = v "-noref"
      lo = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", lo)
      if (!match($0, / cand=[0-9]+ rc=0/)) v = v "-nocount"
      c = substr($0, RSTART, RLENGTH); sub(/ rc=0/, "", c); gsub(/[^0-9]/, "", c)
      if (!(c + 0 > 0 && c + 0 < lo + 0)) v = v "-notpartway"
      s = s (s == "" ? "" : " ") v }
    END { print s " rc=" rc }' "$WORK/out.txt")
  plant early-exit "$exp" "$got"
}
do_shimvis() {
  local d="$WORK/shimvis" n r1 r2
  mkdir -p "$d"
  "$GRADE" --shim "$PLANTS/shim_probe.lua" "$d/shim" || { plant shim-visible identical "shim rc=$?"; return; }
  (cd "$PLANTS" && timeout 30 "$REF" shim_probe.lua >"$d/plain.out" 2>/dev/null); r1=$?
  (cd "$d/shim" && timeout 30 "$REF" shim_probe.lua >"$d/shim.out" 2>"$d/shim.err"); r2=$?
  n=$(wc -l <"$d/plain.out")
  if [[ $r1 -eq 0 && $r2 -eq 0 && $n -ge 25 ]] && grep -q '^EIGENLUA-ASSERTS:[1-9]' "$d/shim.err" \
      && cmp -s "$d/plain.out" "$d/shim.out"; then
    plant shim-visible identical identical
  else
    plant shim-visible identical "rc=$r1/$r2 lines=$n $(diff "$d/plain.out" "$d/shim.out" | head -n 3 | tr '\n' ' ')"
  fi
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
do_crash() {
  run_at_grade "$GRADE" --candidate "$PLANTS/crash.sh" --ref "$REF" --tier D --only int_one_vs_one.lua
  local n sum exp="CRASH crash=1 rc=1" got
  n=$(awk '/^ROW / && $4=="CRASH"{c++} END{print c+0}' "$WORK/out.txt")
  sum=$(summary_line)
  if [[ $GRADE_RC -eq 1 && $n -eq 1 && $sum == *'crash=1'* ]]; then got=$exp; else got="rc=$GRADE_RC n=$n $sum"; fi
  plant crash "$exp" "$got"
}
do_unsupported() {
  run_at_grade "$GRADE" --candidate "$PLANTS/unsupported.sh" --ref "$REF" --tier D --only int_one_vs_one.lua
  local n sum exp="UNSUPPORTED unsupported=1 rc=1" got
  n=$(awk '/^ROW / && $4=="UNSUPPORTED"{c++} END{print c+0}' "$WORK/out.txt")
  sum=$(summary_line)
  if [[ $GRADE_RC -eq 1 && $n -eq 1 && $sum == *'unsupported=1'* ]]; then got=$exp; else got="rc=$GRADE_RC n=$n $sum"; fi
  plant unsupported "$exp" "$got"
}
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
do_nocand() {
  run_at_grade "$GRADE" --candidate "$PLANTS/missing-candidate" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness no-candidate "not executable"
}
do_wrongref() {
  run_at_grade "$GRADE" --candidate "$REF" --ref "$PLANTS/wrong-ref.sh" --tier D --only int_one_vs_one.lua
  harness wrong-ref "not 5.4.9"
}
do_orphan() {
  local dest
  dest=$(stage "$WORK/orphan")
  printf '%s\n' '-- surface: orphan not in the manifest' 'print(1)' >"$dest/corpus/D/orphan_extra.lua"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness orphan-file "not in manifest"
}
do_edited() {
  local dest f b nb
  dest=$(stage "$WORK/edited")
  f="$dest/corpus/lua-tests/literals.lua"
  b=$(od -An -tu1 -N1 "$f" | tr -d '[:space:]')
  nb=$(( (b + 1) % 256 ))
  printf "\\$(printf '%03o' "$nb")" | dd of="$f" bs=1 count=1 conv=notrunc status=none
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier S --only goto.lua
  harness edited-test "checksum mismatch"
}
do_nondet() {
  local dest
  dest=$(stage "$WORK/nondet")
  cat >"$dest/corpus/D/int_one_vs_one.lua" <<'EOF'
-- surface: integers 1 versus 1.0 printing
print(os.time(), os.clock(), tostring({}))
EOF
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier D --only int_one_vs_one.lua
  harness nondet-D "nondeterministic"
}
do_unstable() {
  FLAKY_STATE="$WORK/flaky.n" run_at_grade "$GRADE" --candidate "$REF" --ref "$PLANTS/flaky-ref.sh" --tier S --only goto.lua
  local got
  got="$(awk '/^ROW /{print $3 "=" $4}' "$WORK/out.txt") rc=$GRADE_RC"
  plant unstable-ref "goto.lua=UNSTABLE rc=1" "$got"
}
do_staleband() {
  local dest
  dest=$(stage "$WORK/stale")
  sed -i 's/^include goto\.lua$/band goto.lua plant: a deterministic row declared band/' "$dest/corpus/S.manifest"
  run_at_grade "$dest/tools/grade.sh" --candidate "$REF" --ref "$REF" --tier S --only goto.lua
  harness stale-band "declared band but"
}
dispatch() {
  case $1 in
    canary) do_canary ;;
    perturb) do_perturb ;;
    silent) do_silent ;;
    early-exit) do_early ;;
    shim-visible) do_shimvis ;;
    unstable-ref) do_unstable ;;
    stale-band) do_staleband ;;
    hang) do_hang ;;
    crash) do_crash ;;
    unsupported) do_unsupported ;;
    no-candidate) do_nocand ;;
    wrong-ref) do_wrongref ;;
    orphan-file) do_orphan ;;
    edited-test) do_edited ;;
    nondet-D) do_nondet ;;
    *) printf 'selftest: unknown plant %s\n' "$1" >&2; bad=1 ;;
  esac
}
if [[ $# -gt 1 ]]; then
  printf 'selftest: pass one plant name or none\n' >&2
  exit 1
fi
if [[ $# -eq 1 ]]; then
  dispatch "$1"
else
  for p in canary perturb silent early-exit shim-visible unstable-ref stale-band hang crash unsupported no-candidate wrong-ref orphan-file edited-test nondet-D; do
    dispatch "$p"
  done
fi
exit "$bad"
