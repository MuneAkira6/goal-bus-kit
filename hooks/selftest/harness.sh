# shellcheck shell=bash
# shellcheck disable=SC2034  # fixtures and results defined here are read by the test files that source this harness
# harness.sh — shared by bus-tests.sh and gate-tests.sh.
# Fixtures are built from the installed bus.config.sh (goal names, headers, special verdict, weasel
# words), so a green run means "this configuration is coherent on this machine".

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$(cd "$TEST_DIR/.." && pwd)"
. "$HOOK_DIR/bus.config.sh"
. "$HOOK_DIR/lib/common.sh"

GOAL_A="$(printf '%s\n' $GOAL_LIST | sed -n 1p)"; GOAL_A="${GOAL_A:-G0}"
GOAL_B="$(printf '%s\n' $GOAL_LIST | sed -n 2p)"; GOAL_B="${GOAL_B:-G1}"
W1="$(printf '%s' "$WEASEL_WORDS" | cut -d'|' -f1)"

T_PASS=0; T_FAIL=0; T_SKIP=0
ok()    { T_PASS=$((T_PASS + 1)); printf 'ok    %s\n' "$1"; }
ng()    { T_FAIL=$((T_FAIL + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
skip()  { T_SKIP=$((T_SKIP + 1)); printf 'skip  %s (%s)\n' "$1" "$2"; }
eq()    { if [ "$2" = "$3" ]; then ok "$1"; else ng "$1" "expected [$2] got [$3]"; fi; }
has()   { case "$3" in *"$2"*) ok "$1" ;; *) ng "$1" "expected to contain [$2]; got [$(printf '%s' "$3" | head -c 400)]" ;; esac; }
lacks() { case "$3" in *"$2"*) ng "$1" "expected NOT to contain [$2]" ;; *) ok "$1" ;; esac; }
finish() {
  echo
  echo "selftest: $T_PASS passed, $T_FAIL failed, $T_SKIP skipped"
  [ "$T_FAIL" -eq 0 ] && echo "selftest: all passed"
  [ "$T_FAIL" -eq 0 ]
}

# --- a throwaway repository with the hooks installed exactly as they are here ----------------------
SB=""
new_sandbox() {
  [ -n "$SB" ] && rm -rf "$SB"
  SB="$(mktemp -d)"
  mkdir -p "$SB/.claude/hooks" "$SB/specs/t" "$SB/home/.claude/projects" "$SB/bin" "$SB/fake"
  cp -R "$HOOK_DIR/." "$SB/.claude/hooks/"
  cp "$TEST_DIR/fake-claude" "$SB/bin/claude"; chmod +x "$SB/bin/claude"
  printf '# protocol\n' > "$SB/specs/t/BUS-PROTOCOL.md"
  TD="$SB/specs/t"
}
cleanup_sandbox() { [ -n "$SB" ] && rm -rf "$SB"; SB=""; }
trap cleanup_sandbox EXIT

# run <hook-script> [args...] with the payload in $PAYLOAD and extra env in the array EXTRA.
# The operator's GOALBUS_ENV_FILE never reaches the sandbox: it exists to hand the operator's own
# environment to bus calls, and on a real host one that points CLAUDE_CONFIG_DIR elsewhere failed six
# cases during install. Other GOALBUS_* values are configuration and are tested as configured.
EXTRA=()
run_in_sandbox() {
  local script="$1"; shift
  printf '%s' "${PAYLOAD:-}" | (cd "$SB" && env -u GOALBUS_NESTED -u GOALBUS_ENV_FILE \
      CLAUDE_PROJECT_DIR="$SB" HOME="$SB/home" CLAUDE_CONFIG_DIR="$SB/home/.claude" \
      PATH="$SB/bin:$PATH" FAKE_DIR="$SB/fake" FAKE_TASK_DIR="$TD" GOALBUS_PACK_PATH=specs/t \
      ${EXTRA[@]+"${EXTRA[@]}"} bash "$SB/.claude/hooks/$script" "$@") > "$SB/out" 2> "$SB/err"
  RC=$?
  OUT="$(tr -d '\r' < "$SB/out")"; ERR="$(tr -d '\r' < "$SB/err")"
}
bus()  { run_in_sandbox goal-bus.sh "$@"; }
gate() { run_in_sandbox evidence-gate.sh "$@"; }

payload() { jq -cn --arg s "$1" --arg m "$2" '{session_id: $s, hook_event_name: "Stop", last_assistant_message: $m}' | tr -d '\r'; }
arm_bus() { touch "$TD/.relay-on"; echo "bus-0000-sid" > "$TD/.bus-sid"; }
fake()     { printf '%s' "$2" > "$SB/fake/$1"; }          # fake <file> <content>  (applies to every call)
fake_n()   { printf '%s' "$3" > "$SB/fake/$1.$2"; }       # fake_n <file> <call-no> <content>
calls()    { cat "$SB/fake/count" 2>/dev/null || echo 0; }
state()    { local STATE_PATH="$TD/.relay-state"; st_get "$1"; }

# --- fixtures --------------------------------------------------------------------------------------
HDR="| AC | Item | Plan | $VERDICT_HEADER | $EVIDENCE_HEADER |
| --- | --- | --- | --- | --- |"
pass_row()  { echo "| $1 | item | measure | **PASS** | observed \`ok-$1\` |"; }
empty_row() { echo "| $1 | item | measure | | |"; }
section()   { printf '\n## %s — %s\n\n%s\n' "$1" "$2" "$HDR"; }

progress_partial() { { echo "# P"; section "$GOAL_A" first; pass_row AC-1; empty_row AC-2; section "$GOAL_B" second; empty_row AC-1; } > "$TD/PROGRESS.md"; }
progress_g1_full() { { echo "# P"; section "$GOAL_A" first; pass_row AC-1; pass_row AC-2; section "$GOAL_B" second; empty_row AC-1; } > "$TD/PROGRESS.md"; }
progress_all_full() { { echo "# P"; section "$GOAL_A" first; pass_row AC-1; pass_row AC-2; section "$GOAL_B" second; pass_row AC-1; } > "$TD/PROGRESS.md"; }
progress_g1_bad() {
  { echo "# P"; section "$GOAL_A" first; pass_row AC-1
    echo "| AC-2 | item | measure | PASS | I checked it and it is right |"
    section "$GOAL_B" second; empty_row AC-1; } > "$TD/PROGRESS.md"
}

R_PASS="I re-ran the check myself and read the diff hunk by hunk.
BUS-VERDICT: PASS
BUS-NEXT-BEGIN
Next goal: implement the second part.
BUS-NEXT-END"
R_REJECT="Row AC-2 quotes nothing that was observed.
BUS-VERDICT: REJECT
BUS-NEXT-BEGIN
Re-measure AC-2 and quote the output.
BUS-NEXT-END"
R_ESCALATE="This needs a scope decision I cannot make.
BUS-VERDICT: ESCALATE
BUS-NEXT-BEGIN
Decide whether the export belongs to this task.
BUS-NEXT-END"
R_DONE="Everything is in place.
BUS-VERDICT: DONE
BUS-NEXT-BEGIN
All goals are done.
BUS-NEXT-END"

M_MID="Judged AC-1.
PROGRESS: $GOAL_A ac_done=1/2 pass=1 fail=0 blocked=0 deferred=0"
M_DONE="Every row of $GOAL_A has a verdict.
PROGRESS: $GOAL_A COMPLETE"
