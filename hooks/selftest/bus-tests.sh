#!/usr/bin/env bash
# bus-tests.sh — selftests for goal-bus.sh (run: bash .claude/hooks/goal-bus.sh --selftest).
# A stand-in CLI (fake-claude) and a throwaway sandbox repository are used, so the real claude CLI
# is never called and no real bus is woken. A label such as [L15] names the lesson in
# docs/lessons.md whose guard the case protects; cases marked "manufactured" create the condition a
# guard exists for and check that it fires.
# shellcheck disable=SC2034  # PAYLOAD, EXTRA and PROGRESS are read by functions in the harness and the library
set -uo pipefail
# shellcheck source=harness.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/harness.sh"

echo "goal-bus selftest — goals $GOAL_A $GOAL_B · headers $VERDICT_HEADER/$EVIDENCE_HEADER · awk $GB_AWK"
echo

# Every case runs with a hostile operator environment: an env file that sends CLAUDE_CONFIG_DIR
# elsewhere. The sandbox must not see it (a case that wants one sets it through EXTRA).
POISON_DIR="$(mktemp -d)"; trap 'cleanup_sandbox; rm -rf "$POISON_DIR"' EXIT
printf 'export CLAUDE_CONFIG_DIR=%s/elsewhere\n' "$POISON_DIR" > "$POISON_DIR/operator.env"
export GOALBUS_ENV_FILE="$POISON_DIR/operator.env"

# ================================================================ protocol lines ====
sig() { if has_signature "$1"; then echo yes; else echo no; fi; }
eq "[L15] signature: a progress line"                        yes "$(sig "PROGRESS: $GOAL_A ac_done=3/9 pass=2")"
eq "[L15] signature: a boundary line"                        yes "$(sig "PROGRESS: $GOAL_A COMPLETE")"
eq "[L15] signature: a suffixed goal"                        yes "$(sig "PROGRESS: ${GOAL_A}b COMPLETE")"
eq "[L15] signature: BLOCKED without a goal"                 yes "$(sig 'PROGRESS: BLOCKED the stack does not start')"
eq "[L15] signature: markdown decoration is allowed"         yes "$(sig "- **PROGRESS: $GOAL_B ac_done=1/4**")"
eq "[L15] signature: after report prose"                     yes "$(sig "$(printf 'A paragraph of report.\nPROGRESS: %s ac_done=2/7\n' "$GOAL_B")")"
eq "[L15] not a worker: a file:line citation"                no  "$(sig 'see PROGRESS:584-595 for the history')"
eq "[L15] not a worker: a mention inside a sentence"         no  "$(sig "the line PROGRESS: $GOAL_A is where it failed")"
eq "[L15] not a worker: talking about the prefix"            no  "$(sig 'the hooks recognise workers by the PROGRESS: prefix')"
eq "[L15] not a worker: plain prose"                         no  "$(sig "I finished $GOAL_A")"

eq "[L17] boundary: COMPLETE"                                COMPLETE "$(closing_kind "PROGRESS: $GOAL_A COMPLETE")"
eq "[L17] boundary: BLOCKED with a goal name"                BLOCKED  "$(closing_kind "PROGRESS: $GOAL_B BLOCKED no stack")"
eq "[L17] boundary: the goal comes from the line"            "$GOAL_B"   "$(closing_goal "PROGRESS: $GOAL_B BLOCKED no stack")"
eq "[L17] boundary: BLOCKED without a name has no goal"      ""       "$(closing_goal 'PROGRESS: BLOCKED no stack')"
eq "[L28] boundary: name after BLOCKED is still booked"      "$GOAL_B"   "$(closing_goal "PROGRESS: BLOCKED $GOAL_B no stack")"
eq "[L30] boundary: a progress line is not a boundary"       ""       "$(closing_kind "PROGRESS: $GOAL_A ac_done=3/9")"
eq "[L17] boundary: a quoted line earlier cannot steal it"   "$GOAL_A"   "$(closing_goal "$(printf 'Earlier I wrote\nPROGRESS: G9 ac_done=1/2\nand now:\nPROGRESS: %s COMPLETE\n' "$GOAL_A")")"
eq "[L20] boundary: the last signature line decides"         COMPLETE "$(closing_kind "$(printf 'PROGRESS: %s BLOCKED db down\nfixed it\nPROGRESS: %s COMPLETE\n' "$GOAL_A" "$GOAL_A")")"

eq "[L26] verdict: bare"                                     PASS     "$(printf 'text\nBUS-VERDICT: PASS\n' | read_verdict)"
eq "[L26] verdict: bold, as real replies write it"           ESCALATE "$(printf '**BUS-VERDICT: ESCALATE**\n' | read_verdict)"
eq "[L26] verdict: list and quote prefixes"                  REJECT   "$(printf -- '- __BUS-VERDICT: REJECT__\n' | read_verdict)"
eq "[L26] verdict: an explanation earlier, the real one last" REJECT  "$(printf 'Note: BUS-VERDICT: PASS is not the same as an AC PASS.\nBUS-VERDICT: PASS\nMore.\n**BUS-VERDICT: REJECT**\n' | read_verdict)"
eq "[L26] verdict: none"                                     ""       "$(printf 'no verdict here\n' | read_verdict)"
eq "[L26] body: bold markers"                                "do this" "$(printf '**BUS-NEXT-BEGIN**\ndo this\n**BUS-NEXT-END**\n' | read_next_block)"
eq "[L26] body: the last block wins"                         "real"   "$(printf 'BUS-NEXT-BEGIN\nexample\nBUS-NEXT-END\nBUS-NEXT-BEGIN\nreal\nBUS-NEXT-END\n' | read_next_block)"
eq "[L26] body: two lines survive"                           2        "$(printf 'BUS-NEXT-BEGIN\none\ntwo\nBUS-NEXT-END\n' | read_next_block | wc -l | tr -d ' ')"

# ================================================================ state and tables ====
T="$(mktemp -d)"
STATE_PATH="$T/state"; st_put wakeups 3; st_put goal X9; st_put wakeups 4
eq "state: last write wins"                                  4  "$(st_get wakeups)"
eq "state: other keys survive"                               X9 "$(st_get goal)"
eq "state: increment"                                        5  "$(st_bump wakeups)"
{ echo "# P"; section "$GOAL_A" first; pass_row AC-1; empty_row AC-2
  printf '\n### sub-section of %s\n\n%s\n' "$GOAL_A" "$HDR"; empty_row AC-3
  section "$GOAL_B" second; empty_row AC-1
  printf '\n## Appendix — not a goal\n\n%s\n' "$HDR"; empty_row AC-9; } > "$T/P.md"
eq "[L7] open_rows: counts the goal's rows, h3 stays inside"  2 "$(open_rows "$GOAL_A" "$T/P.md")"
eq "[L7] open_rows: an appendix h2 ends the last goal"        1 "$(open_rows "$GOAL_B" "$T/P.md")"
eq "[L7] open_rows: an unknown goal has none"                 0 "$(open_rows G999 "$T/P.md")"
PROGRESS_MD="$T/P.md"
eq "current goal: the first goal with an empty verdict"      "$GOAL_A" "$(open_goal)"
{ echo "# P"; section "$GOAL_A" first; pass_row AC-1; section "$GOAL_B" second; pass_row AC-1; } > "$T/full.md"
PROGRESS_MD="$T/full.md"; rm -f "$STATE_PATH"
eq "[L16] skipped goal: silent without any booked verdict"   "" "$(unreviewed_goal)"
st_put "ruled_$GOAL_A" PASS
eq "[L16] skipped goal: a full table without a verdict"      "$GOAL_B" "$(unreviewed_goal)"
# [L25] the separator row must be recognised without interval regexes, or every table reads as empty
{ printf '## %s — sep\n\n' "$GOAL_A"; printf '| a | %s | %s |\n|:--|---:|:-:|\n| x | | |\n' "$VERDICT_HEADER" "$EVIDENCE_HEADER"; } > "$T/sep.md"
eq "[L25] separator rows with colons are recognised"         1 "$(open_rows "$GOAL_A" "$T/sep.md")"
for alt in mawk gawk; do
  if command -v "$alt" >/dev/null 2>&1; then
    eq "[L25] the table parser agrees under $alt"            2 "$(GB_AWK="$alt" open_rows "$GOAL_A" "$T/P.md")"
  else
    skip "[L25] the table parser agrees under $alt" "$alt not installed"
  fi
done

# ================================================================ transcripts and results ====
cat > "$T/t.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"m1","usage":{"cache_creation_input_tokens":40,"cache_read_input_tokens":300,"input_tokens":7}}}
{"message":{"content":"carry on","role":"user"},"type":"user"}
{"type":"assistant","message":{"id":"m2","usage":{"cache_creation_input_tokens":250,"cache_read_input_tokens":1740,"input_tokens":10}}}
EOF
eq "[L2] context: the last usage entry, not a sum"           2000 "$(tokens_in_transcript "$T/t.jsonl")"
printf 'not json at all\n' >> "$T/t.jsonl"
eq "[L2] context: broken lines are tolerated"                2000 "$(tokens_in_transcript "$T/t.jsonl")"
eq "[L2] context: a missing transcript reads 0"              0    "$(tokens_in_transcript "$T/none.jsonl")"
cat > "$T/r.jsonl" <<'EOF'
{"type":"assistant","message":{"id":"a1","content":[{"type":"text","text":"an early answer"}]}}
{"message":{"content":"next, please","role":"user"},"type":"user"}
{"type":"assistant","message":{"id":"a2","content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"PROGRESS.md"}}]}}
{"type":"assistant","message":{"id":"a3","content":[{"type":"text","text":"the review, first line\nBUS-VERDICT: PASS"}]}}
EOF
printf 'garbage\n' >> "$T/r.jsonl"
eq "[L5] recover: the last text, ready for the parser"       PASS "$(final_reply_text "$T/r.jsonl" | read_verdict)"
eq "[L5] recover: tool calls and broken lines are skipped"   "the review, first line" "$(final_reply_text "$T/r.jsonl" | head -n 1)"

okj='{"is_error":false,"result":"reviewed","total_cost_usd":1.58}'
succ() { if call_ok "$1" "$2"; then echo ok; else echo no; fi; }
quot() { if hit_usage_limit "$1" "$(result_json "$1")" "$2"; then echo stop; else echo go; fi; }
eq "[L3] success: is_error false counts as success"          ok "$(succ "$okj" reviewed)"
eq "[L3] success: is_error true is a failure"                no "$(succ '{"is_error":true,"result":"x"}' x)"
eq "[L3] success: a missing is_error is not success"         no "$(succ '{"result":"x"}' x)"
eq "[L4] quota: success plus a limit notice is still success" go "$(quot "$(printf '%s\nClaude usage limit reached · resets at 10am' "$okj")" reviewed)"
eq "[L4] quota: a failed call with a limit notice stops"     stop "$(quot 'Claude usage limit reached · resets at 10am' '')"
eq "[L4] quota: is_error true with 429 stops"                stop "$(quot "$(printf '{"is_error":true,"result":""}\n429 too many requests')" '')"
eq "[L4] quota: a plain failure is not a quota stop"         go   "$(quot 'connection reset by peer' '')"
eq "result: the JSON line is found among stderr lines"       reviewed "$(result_json "$(printf 'warning: x\n%s\nmore stderr' "$okj")" | jqr -r .result)"
rm -rf "$T"

# ================================================================ structure ====
src="$HOOK_DIR/lib/common.sh"
fn="$("$GB_AWK" '/^claude_call\(\) \{/{f=1} f{print} f&&/^}/{exit}' "$src")"
calls_outside="$(cat "$HOOK_DIR"/*.sh "$HOOK_DIR"/lib/common.sh | grep -nE '(^|[^_a-zA-Z-])claude +(--|-p|"\$flag")' | grep -v 'claude_call' | wc -l | tr -d ' ')"
eq "[L18] one call site: claude is invoked only in claude_call" 1 "$calls_outside"
has "[L18] the call carries GOALBUS_NESTED=1"                 "env GOALBUS_NESTED=1" "$fn"
has "[L18] the call carries --allowedTools"                  "--allowedTools" "$fn"
has "[L18] the call closes stdin"                            "< /dev/null" "$fn"
has "[kit] the call passes the configured model"             '--model "$BUS_MODEL"' "$fn"

# ================================================================ the hook, end to end ====
new_sandbox
progress_partial
PAYLOAD="$(payload worker-1 "$M_MID")"
bus; eq "[L6] not armed: a complete no-op"                   "0|" "$RC|$OUT$ERR"
touch "$TD/.relay-on"
bus; has "[L13] armed without .bus-sid: says so and lets go" "--seed" "$OUT"; eq "[L13] ... exit 0" 0 "$RC"
arm_bus
PAYLOAD="$(payload bus-0000-sid "$M_MID")"
bus; eq "[L6] the bus's own session is never driven"         "0|" "$RC|$OUT$ERR"
PAYLOAD="$(payload worker-1 "$M_MID")"
EXTRA=(GOALBUS_NESTED=1); bus; EXTRA=()
eq "[L6] a session started by the hook is ignored"           "0|" "$RC|$OUT$ERR"
PAYLOAD="$(payload human-1 'Could you explain the diff?')"
bus; eq "[L6] a session without the signature is ignored"    "0|" "$RC|$OUT$ERR"

PAYLOAD="$(payload worker-1 "$M_MID")"
bus
eq  "[L8] mid-goal: the hook drives the next turn (exit 2)" 2 "$RC"
has "[L8] mid-goal: names the goal and the empty rows"      "Continue $GOAL_A: 1 row(s)" "$ERR"
has "[L20] mid-goal: repeats that a turn must end on a boundary line" "wakes nobody" "$ERR"
eq  "[L8] mid-goal: the bus is not woken"                   0 "$(calls)"
eq  "worker session is recorded"                            worker-1 "$(state worker_sid)"
EXTRA=(GOALBUS_TURN_LIMIT=2); bus; EXTRA=()
eq  "[L19] manufactured: the turn cap fires"                0 "$RC"
has "[L19] ... and says why"                                "turns without finishing" "$OUT"

PAYLOAD="$(payload worker-1 "$M_DONE")"
bus
eq  "[L7] COMPLETE with an empty verdict bounces (exit 2)" 2 "$RC"
has "[L7] ... and says how many rows are empty"            "1 row(s) in its section" "$ERR"
eq  "[L7] ... without waking the bus"                      0 "$(calls)"

progress_g1_bad
bus
eq  "[gate] a quote-less PASS bounces at the boundary"       2 "$RC"
has "[gate] ... with the finding"                    "without a quote mark" "$ERR"
eq  "[gate] ... without waking the bus"                     0 "$(calls)"
EXTRA=(GOALBUS_GATE_BLOCK_LIMIT=1); bus; EXTRA=()
eq  "[L19] manufactured: the gate releases to the bus at its cap" 1 "$(calls)"
has "[L19] ... and the bus is told why"                    "released this to you" "$(cat "$SB/fake/prompt.1")"
eq  "[kit] relay-side gate blocks are counted in total"    2 "$(state gate_blocks_all)"

new_sandbox; arm_bus; progress_g1_full
fake reply "$R_PASS"
PAYLOAD="$(payload worker-1 "$M_DONE")"
bus
eq  "PASS: the next instructions go to the worker (exit 2)" 2 "$RC"
has "PASS: ... verbatim"                                   "Next goal: implement the second part." "$ERR"
eq  "PASS: the bus was woken once"                         1 "$(calls)"
has "PASS: the wake-up names the goal"                     "$GOAL_A is complete." "$(cat "$SB/fake/prompt.1")"
has "[L18] the wake-up ran with GOALBUS_NESTED=1"           "child=1|mode=resume|sid=bus-0000-sid" "$(cat "$SB/fake/calls.log")"
has "PASS: BUS-LOG records the verdict"                    "**Verdict: PASS**" "$(cat "$TD/BUS-LOG.md")"
lacks "[L29] BUS-LOG keeps only the instructions"          "hunk by hunk" "$(cat "$TD/BUS-LOG.md")"
has "[L29] BUS-REVIEWS keeps the review prose"             "hunk by hunk" "$(cat "$TD/BUS-REVIEWS.md")"
eq  "[L16] the verdict is booked to the goal"              PASS "$(state "ruled_$GOAL_A")"
eq  "PASS: the instructions are saved for --next"          "Next goal: implement the second part." "$(cat "$TD/.next-step")"
eq  "cost: the CLI-reported cost is added up"              0.5000 "$(state bus_cost_usd)"
eq  "[L2] context: read from the bus transcript"           1000 "$(state bus_tokens)"

new_sandbox; arm_bus; progress_g1_full
fake reply "$R_REJECT"; PAYLOAD="$(payload worker-1 "$M_DONE")"
bus
eq  "REJECT: the findings go back (exit 2)"                2 "$RC"
has "REJECT: ... verbatim"                                 "Re-measure AC-2" "$ERR"
eq  "REJECT: consecutive count"                            1 "$(state "rejects_streak_$GOAL_A")"
EXTRA=(GOALBUS_REJECT_LIMIT=2); bus; EXTRA=()
eq  "[L19] manufactured: the reject cap stops for a human" 0 "$RC"
has "[L19] ... and says so"                                "rejected $GOAL_A 2 times" "$OUT"
fake reply "$R_PASS"; bus
eq  "[kit] a PASS clears the consecutive count"            0 "$(state "rejects_streak_$GOAL_A")"
eq  "[kit] ... but the reject history stays"               2 "$(state "rejects_all_$GOAL_A")"
EXTRA=(GOALBUS_PACK_PATH=specs/t); bus --status; EXTRA=()
has "[L16] --status shows what was reviewed, with rejects" "$GOAL_A:PASS(rejected 2x)" "$OUT"

new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_ESCALATE"; bus
eq  "ESCALATE: stops for the human (exit 0)"               0 "$RC"
has "ESCALATE: tells the human how to answer"              "--notify" "$OUT"
has "ESCALATE: the question is kept for --next"            "Decide whether" "$(cat "$TD/.next-step")"
fake reply "$R_DONE"; bus
has "DONE: stops (exit 0) and says so"                     "every goal done" "$OUT"
fake reply "I think it is fine."; bus
has "[L13] no parsable verdict: stops for a human"         "no parsable BUS-VERDICT" "$OUT"
has "[L13] ... and logs UNPARSED"                          "**Verdict: UNPARSED**" "$(cat "$TD/BUS-LOG.md")"

new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_PASS"; fake stderr "Claude usage limit reached · resets at 10am"
bus
eq  "[L4] a paid review with a limit notice still counts as PASS" 2 "$RC"
eq  "[L4] ... and is billed"                               1 "$(state wakeups)"
rm -f "$SB/fake/stderr"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake is_error true; fake stderr "Claude usage limit reached · resets at 10am"
bus
eq  "[L27] a real usage limit stops without retrying (exit 0)" 0 "$RC"
eq  "[L27] ... the wake-up is refunded"                    0 "$(state wakeups)"
eq  "[L27] ... and counted as a quota stop"                1 "$(state limit_stops)"
has "[L5] ... and the log points to --recover"             "--recover" "$(cat "$TD/BUS-LOG.md")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake is_error true; fake exit_code 1
bus
has "[L13] a failed wake-up stops and points to --recover" "--recover" "$OUT"
eq  "[L13] ... and is refunded"                            0 "$(state wakeups)"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
AT='@'  # built at run time, so this file holds no literal credential URL for leak scanners to flag
fake is_error true; fake exit_code 1; fake stderr "Not logged in · Please run /login (via http://user:s3cret${AT}proxy.example:8080)"
bus
has "[kit] a failed wake-up writes why into the ledger"    "Not logged in" "$(cat "$TD/BUS-LOG.md")"
has "[kit] ... an auth failure points to GOALBUS_ENV_FILE" "GOALBUS_ENV_FILE" "$OUT"
lacks "[kit] ... and a credential inside a URL is masked"  "s3cret" "$(cat "$TD/BUS-LOG.md")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake is_error true; fake exit_code 1; fake stderr "request 0c4291ab-77e0 failed, cost 0.1429"
bus
has "[kit] a 429 inside an id or a cost is not a usage limit" "waking the bus failed" "$(cat "$TD/BUS-LOG.md")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
printf 'export FAKE_ENVMARK=from-env-file\n' > "$SB/bus.env"
EXTRA=(GOALBUS_ENV_FILE="$SB/bus.env"); fake reply "$R_PASS"; bus; EXTRA=()
has "[kit] the bus call sources GOALBUS_ENV_FILE first"   "from-env-file" "$(cat "$SB/fake/envmarks.log" 2>/dev/null)"
eq  "[kit] ... and the review goes through"                2 "$RC"

new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
EXTRA=(GOALBUS_WAKE_LIMIT=1); fake reply "$R_REJECT"; bus; bus; EXTRA=()
eq  "[L19] manufactured: the review cap refuses the next wake-up" 1 "$(calls)"
has "[L19] ... and says so"                                "reached the cap" "$OUT"

new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_PASS"; fake ctx 900000
bus
eq  "[L12] rotation: a new bus session at a clean PASS"    yes "$([ "$(tr -d ' \r\n' < "$TD/.bus-sid")" != bus-0000-sid ] && echo yes || echo no)"
eq  "[L12] rotation: counted"                              1 "$(state handovers)"
has "[L12] rotation: lineage in BUS-LOG"                   "parent: \`bus-0000-sid\`" "$(cat "$TD/BUS-LOG.md")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_PASS"; fake ctx 900000; touch "$SB/fake/no_handoff"
bus
eq  "[L12] rotation: no handoff written keeps the old bus" bus-0000-sid "$(tr -d ' \r\n' < "$TD/.bus-sid")"
has "[L12] ... and the worker is told"                     "rotation failed" "$ERR"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
echo "a handoff from an earlier rotation" > "$TD/BUS-HANDOFF.md"
fake reply "$R_PASS"; fake ctx 900000; touch "$SB/fake/no_handoff"
bus
eq  "[L19] manufactured: a stale BUS-HANDOFF.md does not pass for a new one" bus-0000-sid "$(tr -d ' \r\n' < "$TD/.bus-sid")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_PASS"; fake ctx 900000; touch "$SB/fake/no_ready"
bus
eq  "[L12] rotation: a successor that never says BUS-READY is not installed" bus-0000-sid "$(tr -d ' \r\n' < "$TD/.bus-sid")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_REJECT"; fake ctx 900000
bus
eq  "[L12] no rotation in the middle of a REJECT loop"     bus-0000-sid "$(tr -d ' \r\n' < "$TD/.bus-sid")"
new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_PASS"; touch "$SB/fake/no_transcript"
bus
has "[L2] an unreadable bus transcript is reported, not silent" "Rotation can never fire" "$(cat "$TD/BUS-LOG.md")"

new_sandbox; arm_bus; progress_all_full
printf 'ruled_%s=PASS\n' "$GOAL_A" > "$TD/.relay-state"
fake reply "$R_PASS"
PAYLOAD="$(payload worker-1 "PROGRESS: $GOAL_B ac_done=1/1 pass=1")"
bus
eq  "[L16] manufactured: a goal that skipped its boundary is reviewed" 1 "$(calls)"
has "[L16] ... and the bus is told why"                    "never printed its boundary line" "$(cat "$SB/fake/prompt.1")"
eq  "[L28] ... and the verdict is booked to that goal"     PASS "$(state "ruled_$GOAL_B")"

new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "PROGRESS: $GOAL_A BLOCKED the database is down")"
fake reply "$R_REJECT"; bus
has "[L17] a BLOCKED boundary wakes the bus with its goal" "$GOAL_A reported BLOCKED." "$(cat "$SB/fake/prompt.1")"
eq  "[L17] ... and books the verdict to that goal"         REJECT "$(state "ruled_$GOAL_A")"

new_sandbox; arm_bus; progress_g1_full; PAYLOAD="$(payload worker-1 "$M_DONE")"
fake reply "$R_PASS"; EXTRA=(GOALBUS_PAUSE_AFTER="$GOAL_A"); bus; EXTRA=()
eq  "[kit] planned pause: stops after the listed goal (exit 0)" 0 "$RC"
has "[kit] ... and says how to go on"                      "--next" "$OUT"
eq  "[kit] ... the pause is recorded"                      yes "$([ -f "$TD/.relay-paused" ] && echo yes || echo no)"
PAYLOAD=""; bus --next
eq  "[kit] --next prints the saved instructions"           "Next goal: implement the second part." "$OUT"

# ================================================================ subcommands ====
new_sandbox; progress_partial; PAYLOAD=""
bus --notify ""
eq  "[L18] --notify: nothing to deliver -> 1"              1 "$RC"
bus --notify "a ruling"
eq  "[L18] --notify: no .bus-sid -> 1"                 1 "$RC"
arm_bus; echo 999999 > "$TD/.relay-lock"
bus --notify "a ruling"
eq  "[L18] --notify: a held lock -> 3, nothing woken"      "3|0" "$RC|$(calls)"
eq  "[L18] ... and the other holder's lock is untouched"   999999 "$(tr -d ' \r\n' < "$TD/.relay-lock")"
rm -f "$TD/.relay-lock"; fake reply "Noted. BUS-NEXT-BEGIN
Proceed with the export.
BUS-NEXT-END"
bus --notify "The export stays in scope."
eq  "[L18] --notify: delivered through the one call site"  "0|1" "$RC|$(calls)"
has "[L18] ... logged as a manual delivery"                "Manual delivery" "$(cat "$TD/BUS-LOG.md")"
eq  "[L18] ... and billed"                                 1 "$(state wakeups)"
bus --recover
has "[L5] --recover prints the bus's last reply"           "Proceed with the export." "$OUT"
new_sandbox; PAYLOAD=""
bus --status
has "[L16] --status before the hook ever fired says so"    "has not fired yet" "$OUT"
progress_partial
bus --seed
eq  "[kit] --seed: records the session that answered BUS-READY" 0 "$RC"
eq  "[kit] ... in .bus-sid"                            "$OUT" "$(tr -d ' \r\n' < "$TD/.bus-sid")"
has "[kit] ... started as a new session with GOALBUS_NESTED=1" "child=1|mode=new" "$(cat "$SB/fake/calls.log")"
bus --seed
eq  "[kit] --seed refuses to replace an existing session"  1 "$RC"
new_sandbox; progress_partial; touch "$SB/fake/no_ready"; PAYLOAD=""
bus --seed
eq  "[kit] --seed: no BUS-READY, nothing recorded"         "1|no" "$RC|$([ -f "$TD/.bus-sid" ] && echo yes || echo no)"
echo '{"hooks":{"Stop":[{"hooks":[{"timeout":1800,"command":"bash .claude/hooks/goal-bus.sh","type":"command"}]}]}}' > "$SB/.claude/settings.local.json"
bus --status
has "[L1] manufactured: --status flags a hook timeout that cannot cover a rotation" "must exceed" "$OUT"
new_sandbox; rm -f "$SB/.claude/hooks/bus.config.sh"; PAYLOAD="$(payload worker-1 "$M_MID")"
bus
eq  "[L13] without its configuration the hook is a silent no-op" "0|" "$RC|$OUT$ERR"

# ================================================================ bin/start-worker.sh ====
wsrc="$HOOK_DIR/bin/start-worker.sh"
wfn="$("$GB_AWK" '/^worker_call\(\) \{/{f=1} f{print} f&&/^}/{exit}' "$wsrc")"
has "[L18] the worker is started in one place, never as a hook child" "env -u GOALBUS_NESTED" "$wfn"
has "[kit] the worker uses the configured worker model"      '--model "$WORKER_MODEL"' "$wfn"
eq  "[L18] start-worker has exactly one claude call"         1 "$(grep -cE '(^|[^_a-zA-Z-])claude +"\$flag"' "$wsrc" | tr -d ' ')"
new_sandbox; arm_bus; progress_partial; PAYLOAD=""
run_in_sandbox bin/start-worker.sh "Do $GOAL_A."
eq  "[kit] start-worker: the new worker session is recorded" yes "$([ -s "$TD/.worker-sid" ] && echo yes || echo no)"
has "[kit] ... started as a new session that the hooks will drive" "|child=|mode=new" "$(cat "$SB/fake/calls.log")"
run_in_sandbox bin/start-worker.sh --resume w-123 "continue"
has "[kit] --resume continues the given session"             "mode=resume|sid=w-123" "$(cat "$SB/fake/calls.log")"

# ================================================================ bin/watch.sh ====
new_sandbox; arm_bus; progress_partial; PAYLOAD=""
run_in_sandbox bin/watch.sh --once
eq  "[L30] watch: the first poll only records a baseline"    "" "$OUT"
echo w-1 > "$TD/.worker-sid"; mkdir -p "$SB/home/.claude/projects/p"
printf '{"type":"user","message":{"content":"PROGRESS: %s COMPLETE"}}\n' "$GOAL_A" > "$SB/home/.claude/projects/p/w-1.jsonl"
run_in_sandbox bin/watch.sh --once
lacks "[L30] watch: protocol text read into a transcript is not an event" "[bus]" "$OUT"
# the ledger entry is written by the real hook, not typed here: the watcher must read the format the
# hook actually produces
progress_g1_full; fake reply "$R_PASS"; PAYLOAD="$(payload w-1 "$M_DONE")"; bus; PAYLOAD=""
run_in_sandbox bin/watch.sh --once
has "[L26] watch: reads the verdict from the ledger the hook wrote" "**Verdict: PASS**" "$OUT"
has "[L30] watch: a new BUS-LOG entry is an event"           "[bus]" "$OUT"
has "[L30] watch: progress comes from the hook's own parser" "[progress]" "$OUT"
EXTRA=(STALL_POLLS=2); run_in_sandbox bin/watch.sh --once; run_in_sandbox bin/watch.sh --once; EXTRA=()
has "[L19] manufactured: nothing grows, so a stall is reported" "[stall?]" "$OUT"
printf '%s\n' '{"type":"result","is_error":true,"result":""}' 'API Error: 529 Overloaded' >> "$TD/.worker-output"
run_in_sandbox bin/watch.sh --once
has "[L27] watch: a finished worker is classified"           "overloaded" "$OUT"
has "[L23] ... and the resume command is printed"            "--resume w-1" "$OUT"
printf '=== 2026-09-29 17:40:00 resume worker w-1 (model opus[1m])\n' >> "$TD/.worker-output"
run_in_sandbox bin/watch.sh --once
lacks "[kit] watch: after --resume the old result line is not an end" "[ended]" "$OUT"
printf '%s\n' '{"type":"result","is_error":false,"result":"PROGRESS: G1 COMPLETE"}' >> "$TD/.worker-output"
run_in_sandbox bin/watch.sh --once
has "[kit] ... the resumed process's own result is"          "[ended]" "$OUT"
run_in_sandbox bin/watch.sh --once
lacks "[kit] ... and it is reported once"                    "[ended]" "$OUT"

finish
