#!/usr/bin/env bash
# gate-tests.sh — selftests for evidence-gate.sh (run: bash .claude/hooks/evidence-gate.sh --selftest).
# Fixtures use the configured headers, weasel words, FAIL words and special verdict, so the cases
# stay meaningful under any configuration.
# shellcheck disable=SC2034  # PAYLOAD and EXTRA are read by functions in the harness
set -uo pipefail
# shellcheck source=harness.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/harness.sh"

echo "evidence-gate selftest — headers $VERDICT_HEADER/$EVIDENCE_HEADER · special ${CITE_VERDICT:-(none)} · awk $GB_AWK"
echo

T="$(mktemp -d)"
H="| AC | Item | Plan | $VERDICT_HEADER | $EVIDENCE_HEADER |
| --- | --- | --- | --- | --- |"
# t <name> <expected-exit> <table-rows...>
t() {
  local name="$1" want="$2"; shift 2
  { echo "## $GOAL_A — case"; echo; echo "$H"; printf '%s\n' "$@"; } > "$T/t.md"
  out="$(check_evidence "$T/t.md" t.md)"; got=$?
  if [ "$got" = "$want" ]; then ok "$name"; else ng "$name" "expected exit $want, got $got: $out"; fi
}

t "an empty verdict is allowed (not judged yet)"            0 "| AC-1 | x | measure | | |"
t "PASS with a backtick quotation"                          0 "| AC-1 | x | measure | **PASS** | the sidebar reads \`Users, Reports\` |"
t "PASS with a quotation in CJK brackets"                   0 "| AC-1 | x | measure | PASS | 画面の表示は「保存しました」 |"
t "[gate] PASS with an empty evidence cell"                  1 "| AC-1 | x | measure | **PASS** | |"
t "[gate] PASS with a dash for evidence"                     1 "| AC-1 | x | measure | PASS | — |"
t "[gate] PASS whose evidence uses a weasel phrase"          1 "| AC-1 | x | measure | **PASS** | $W1, \`bundle\` replaced |"
t "[gate] PASS without any quote mark"                       1 "| AC-1 | x | measure | PASS | I looked and it is gone |"
if [ -n "$CITE_VERDICT" ]; then
  t "[L9] $CITE_VERDICT with both citations"             0 "| AC-4 | x | ref | $CITE_VERDICT | \`$CITE_MARK_A:31\` and $CITE_MARK_B measured \`0\` |"
  t "[L9] $CITE_VERDICT with only the first citation"    1 "| AC-4 | x | ref | $CITE_VERDICT | \`$CITE_MARK_A:31\` says 0 |"
else
  t "[L9] no special verdict: PASS(X) follows the PASS rules" 0 "| AC-4 | x | ref | PASS(X) | \`measured output\` |"
  t "[L9] no special verdict: PASS(X) without a quote fails"  1 "| AC-4 | x | ref | PASS(X) | I made sure |"
fi
t "FAIL without the expected/actual shape"                  1 "| AC-1 | x | measure | FAIL | did not work |"
t "FAIL with the expected/actual shape"                     0 "| AC-1 | x | measure | **FAIL** | $FAIL_EXPECTED_WORD \"404\" / $FAIL_ACTUAL_WORD \"/login\" |"
t "BLOCKED without saying what is missing"                  1 "| AC-1 | x | measure | BLOCKED | |"
t "BLOCKED with the missing precondition"                   0 "| AC-1 | x | measure | BLOCKED | the second tenant cannot be created locally |"
t "DEFERRED without what it waits for"                      1 "| AC-3 | x | deferred | DEFERRED | |"
t "DEFERRED with what it waits for"                         0 "| AC-3 | x | deferred | DEFERRED | waits for the provisioning decision |"
t "[kit] an unknown verdict word is refused"                1 "| AC-1 | x | measure | OK | \`200\` |"
t "[kit] an escaped pipe stays inside its cell"             0 "| AC-1 | x | measure | PASS | the header reads \`Users \\| Reports\` |"
if [ -n "$BANNED_VERDICTS" ]; then fv="${BANNED_VERDICTS%%|*}"; fv_env=""; else fv="PASS(REF)"; fv_env="PASS(REF)"; fi
( [ -n "$fv_env" ] && BANNED_VERDICTS="$fv_env"
  t "[kit] a forbidden verdict is refused even with evidence" 1 "| AC-9 | x | measure | $fv | \`spec.ts:372\` and a ledger entry |"
  t "[kit] other verdicts are unaffected by the ban"          0 "| AC-9 | x | measure | **PASS** | observed \`landed\` |"
  echo "$T_PASS $T_FAIL" > "$T/sub" )
read -r sp sf < "$T/sub"; T_PASS=$sp; T_FAIL=$sf

# tables that are not judgment tables must be ignored
printf '## %s — env\n\n| Item | Value | Proof |\n| --- | --- | --- |\n| branch | PASS | |\n' "$GOAL_A" > "$T/env.md"
check_evidence "$T/env.md" >/dev/null; eq "an environment table without a $VERDICT_HEADER column is ignored" 0 $?
printf '## %s — ledger\n\n| # | Goal | Object | Before | Change | Restored |\n| --- | --- | --- | --- | --- | --- |\n| 1 | %s | vhost | none | PASS | |\n' "$GOAL_A" "$GOAL_A" > "$T/ledger.md"
check_evidence "$T/ledger.md" >/dev/null; eq "a ledger table without judgment headers is ignored" 0 $?
printf '## %s — checks\n\n| Check | %s | %s |\n| --- | --- | --- |\n| build | PASS | |\n' "$GOAL_A" "$VERDICT_HEADER" "$EVIDENCE_HEADER" > "$T/checks.md"
check_evidence "$T/checks.md" >/dev/null; eq "a three-column check table is still checked" 1 $?
for alt in mawk gawk; do
  if command -v "$alt" >/dev/null 2>&1; then
    GB_AWK="$alt" check_evidence "$T/checks.md" >/dev/null; eq "[L25] the checker agrees under $alt" 1 $?
  else
    skip "[L25] the checker agrees under $alt" "$alt not installed"
  fi
done
rm -rf "$T"

# ------------------------------------------------------------------ the hook path ----
new_sandbox
{ echo "# P"; section "$GOAL_A" first; echo "| AC-1 | item | measure | PASS | trust me |"; } > "$TD/PROGRESS.md"
PAYLOAD='{}'
gate; eq "[L6] not armed: a complete no-op"                        "0|" "$RC|$OUT$ERR"
touch "$TD/.gate-on"
EXTRA=(GOALBUS_NESTED=1); gate; EXTRA=()
eq "[L6] a session started by the bus is not gated"                0 "$RC"
gate; eq "[gate] armed: a quote-less PASS blocks the turn"          2 "$RC"
has "[gate] ... with the finding and the honest way out"            "downgrade the verdict to BLOCKED" "$ERR"
eq "... and the consecutive count is 1"                            1 "$(cat "$TD/.gate-streak")"
EXTRA=(GOALBUS_GATE_BLOCK_LIMIT=1); gate; EXTRA=()
eq "[L19] manufactured: past the cap the gate lets go (no loop)"   0 "$RC"
has "[L19] ... and says the findings are still there"             "still in PROGRESS.md" "$ERR"
{ echo "# P"; section "$GOAL_A" first; pass_row AC-1; } > "$TD/PROGRESS.md"
echo 3 > "$TD/.gate-streak"
gate; eq "a clean table passes"                                   0 "$RC"
eq "... and resets the consecutive count"                         no "$([ -f "$TD/.gate-streak" ] && echo yes || echo no)"
gate --check; eq "--check: clean -> exit 0"                       0 "$RC"
{ echo "# P"; section "$GOAL_A" first; echo "| AC-1 | item | measure | PASS | |"; } > "$TD/PROGRESS.md"
rm -f "$TD/.gate-on"
gate --check; eq "--check ignores the latch and reports"          1 "$RC"

finish
