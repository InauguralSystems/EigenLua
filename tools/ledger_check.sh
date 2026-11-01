#!/usr/bin/env bash
# tools/ledger_check.sh <rows> [<ledger>]: compare a grade run's ROW lines with
# the divergence ledger, row by row. tools/grade.sh --ledger calls it on its own
# rows; tests/test_ledger_exact_hq58.sh runs its plants through it.
#
# The ledger is LEDGER.md (default: next to tools/). Two tables in it are
# machine-read, and every row of them must parse or this exits 2:
#   "## Tier S" table   | row | verdict | count (ref) | ... |
#     verdict: exactly one of PASS FAIL HANG CRASH UNSUPPORTED UNSTABLE
#              (`**PASS**` is allowed); count: the first token is the row's
#              assert count (an integer) or `none`.
#   "## Tier D: DIVERGE" table   | row | first difference | ... |
#     every row's verdict is DIVERGE; the first difference starts `line <n>`.
#
# A row passes the ledger iff (hq#58 EL-LEDGER-1):
#   - a Tier S ledger row: the observed verdict equals the ledgered one, and if
#     the ledgered count is an integer the observed count is an integer >= it
#     (a higher count passes and is reported as `improved`, to be recorded by
#     editing the ledger; a lower one, `none` or a crash is a mismatch);
#   - a Tier D ledger row: the observed verdict is DIVERGE and the grader's
#     first difference is at the ledgered line;
#   - any other graded row: PASS or MATCH.
# A ledger row the run did not grade exits 2. Exit 0 iff no row mismatches,
# 1 otherwise. Before hq#58 the gate compared only the SET of non-PASS rows,
# so a ledgered row could crash, hang or lose most of its asserts unseen.
set -u
set -o pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROWS=${1:-}
LEDGER_FILE=${2:-$ROOT/LEDGER.md}
die() { printf 'HARNESS %s\n' "$*" >&2; exit 2; }
[[ -n $ROWS && -f $ROWS ]] || die "ledger_check: missing rows file: ${ROWS:-<none>}"
[[ -f $LEDGER_FILE ]] || die "missing divergence ledger: $LEDGER_FILE"

declare -A lv=() lc=() ll=() ov=() oc=() od=()
parsed=$(awk -F'|' '
  function trim(s) { sub(/^[[:space:]]*/, "", s); sub(/[[:space:]]*$/, "", s); return s }
  /^## Tier S / { section = "S"; next }
  /^## Tier D: DIVERGE/ { section = "D"; next }
  /^## / { section = "" }
  section && $2 ~ /^[[:space:]]*[A-Za-z0-9_]+\.lua[[:space:]]*$/ {
    name = trim($2)
    if (section == "S") {
      v = trim($3); gsub(/\*/, "", v)
      c = trim($4); sub(/[[:space:]].*$/, "", c)
      printf "S\t%s\t%s\t%s\n", name, (v == "" ? "-" : v), (c == "" ? "-" : c)
    } else {
      d = trim($3)
      if (match(d, /^line [0-9]+([^0-9]|$)/)) { d = substr(d, 6); sub(/[^0-9].*$/, "", d) } else d = "-"
      printf "D\t%s\tDIVERGE\t%s\n", name, d
    }
  }
' "$LEDGER_FILE") || die "could not read $LEDGER_FILE"
expected_n=0
while IFS=$'\t' read -r tier name verdict val; do
  [[ -n ${tier:-} ]] || continue
  key="$tier/$name"
  [[ -z ${lv[$key]:-} ]] || die "duplicate ledger row: $key"
  if [[ $tier == S ]]; then
    [[ $verdict =~ ^(PASS|FAIL|HANG|CRASH|UNSUPPORTED|UNSTABLE)$ ]] \
      || die "LEDGER.md Tier S row $name: the verdict column must be exactly one verdict, got '$verdict'"
    [[ $val =~ ^([0-9]+|none)$ ]] \
      || die "LEDGER.md Tier S row $name: the count column must start with an integer or none, got '$val'"
    lc[$key]=$val
  else
    [[ $val =~ ^[0-9]+$ ]] \
      || die "LEDGER.md Tier D row $name: the first difference must start 'line <n>'"
    ll[$key]=$val
  fi
  lv[$key]=$verdict
  [[ $verdict == PASS ]] || expected_n=$((expected_n + 1))
done <<<"$parsed"
(( expected_n > 0 )) || die "divergence ledger has no Tier S or Tier D rows"

while read -r tag tier name verdict detail; do
  [[ $tag == ROW ]] || continue
  key="$tier/$name"
  [[ -z ${ov[$key]:-} ]] || die "rows file grades $key twice"
  ov[$key]=$verdict
  od[$key]=${detail:-}
  c=''
  [[ " ${detail:-}" =~ \ count=([^ ]*) ]] && c=${BASH_REMATCH[1]}
  oc[$key]=$c
done <"$ROWS"
(( ${#ov[@]} > 0 )) || die "ledger_check: no ROW lines in $ROWS"

observed_n=0 unexpected_n=0 missing_n=0 mismatch_n=0 improved_n=0
for key in "${!lv[@]}"; do
  [[ -n ${ov[$key]:-} ]] || die "ledger names no graded row: $key"
done
for key in $(printf '%s\n' "${!ov[@]}" | LC_ALL=C sort); do
  v=${ov[$key]}
  case $v in PASS|MATCH) ;; *) observed_n=$((observed_n + 1)) ;; esac
  if [[ -z ${lv[$key]:-} ]]; then
    case $v in
      PASS|MATCH) ;;
      *)
        printf 'LEDGER unexpected %s verdict=%s %s\n' "$key" "$v" "${od[$key]}" >&2
        unexpected_n=$((unexpected_n + 1))
        ;;
    esac
    continue
  fi
  want=${lv[$key]}
  if [[ $want != PASS && ( $v == PASS || $v == MATCH ) ]]; then
    printf 'LEDGER stale %s unexpectedly=%s (ledger says %s: record the fix in LEDGER.md)\n' "$key" "$v" "$want" >&2
    missing_n=$((missing_n + 1))
    continue
  fi
  if [[ ${key%%/*} == S ]]; then
    lcount=${lc[$key]} ocount=${oc[$key]}
    bad=''
    [[ $v == "$want" ]] || bad="verdict"
    if [[ $lcount =~ ^[0-9]+$ ]]; then
      if [[ ! $ocount =~ ^[0-9]+$ ]] || (( ocount < lcount )); then bad="${bad:+$bad,}count"; fi
    fi
    if [[ -n $bad ]]; then
      printf 'LEDGER mismatch %s (%s) ledger=%s count>=%s observed=%s count=%s\n' \
        "$key" "$bad" "$want" "$lcount" "$v" "${ocount:-absent}" >&2
      mismatch_n=$((mismatch_n + 1))
    elif [[ $lcount =~ ^[0-9]+$ ]] && (( ocount > lcount )); then
      printf 'LEDGER improved %s count=%s > ledgered %s (record it in LEDGER.md)\n' "$key" "$ocount" "$lcount"
      improved_n=$((improved_n + 1))
    fi
  else
    line=''
    [[ ${od[$key]} =~ ^line\ ([0-9]+)\  ]] && line=${BASH_REMATCH[1]}
    if [[ $v != DIVERGE || $line != "${ll[$key]}" ]]; then
      printf 'LEDGER mismatch %s ledger=DIVERGE line %s observed=%s %s\n' "$key" "${ll[$key]}" "$v" "${od[$key]}" >&2
      mismatch_n=$((mismatch_n + 1))
    fi
  fi
done
printf 'LEDGER expected=%s observed=%s unexpected=%s missing=%s mismatched=%s improved=%s\n' \
  "$expected_n" "$observed_n" "$unexpected_n" "$missing_n" "$mismatch_n" "$improved_n"
(( unexpected_n == 0 && missing_n == 0 && mismatch_n == 0 ))
