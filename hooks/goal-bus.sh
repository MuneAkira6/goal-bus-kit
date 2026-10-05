#!/usr/bin/env bash
# goal-bus.sh — Stop hook that relays a worker session and a long-lived "bus" session.
#
# The bus is not a fresh reviewer: it is the session that wrote the goal pack and keeps the whole
# context, so it can adjust later goals to what earlier goals actually found.
#
#   the worker ends a turn in the middle of a goal -> count empty verdicts in PROGRESS.md, say "continue"
#   the worker prints "PROGRESS: G1 COMPLETE"      -> table full? evidence gate? then wake the bus
#   the bus answers BUS-VERDICT: PASS              -> the next goal's instructions go to the worker
#                               REJECT             -> the findings go back to the worker
#                               ESCALATE / DONE    -> stop and leave it to the human
#
# Off by default. Arm with: touch <task-dir>/.relay-on      (parameters: bus.config.sh)
# Subcommands for humans:
#   --selftest            run the driver's selftests (never calls the real CLI)
#   --status              where the run is, what was actually reviewed, counters, cost
#   --seed [--force]      start the bus session and record its id in <task-dir>/.bus-sid
#   --notify "<text>"     deliver something to the bus (the only sanctioned way; also reads stdin)
#   --next                print the latest instructions the bus wrote for the worker
#   --recover [id]        print the bus's last reply from its transcript (a lost verdict, unpaid)
#   --reset               clear .relay-state and the lock after a crash (logs are never touched)

set -uo pipefail

HOOK_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$HOOK_DIR/bus.config.sh" ] || [ ! -f "$HOOK_DIR/lib/common.sh" ]; then
  # Without its configuration the hook is a silent no-op; a human asking for something gets an error.
  case "${1:-}" in -*) echo "goal-bus: bus.config.sh or lib/ is missing next to $0 (copy the whole hooks/ directory)" >&2; exit 1 ;; esac
  exit 0
fi
. "$HOOK_DIR/bus.config.sh"
. "$HOOK_DIR/lib/common.sh"
gb_paths

append() { printf '%s\n' "$@" >> "$LEDGER_MD"; }

# ------------------------------------------------------------------- rotation ----
# A long-lived bus eventually fills its context. Instead of growing it, move what matters into files
# and hand over to a fresh session, but only at a clean PASS boundary, never inside a REJECT loop.
hand_over_bus() { # hand_over_bus <old-session> <tokens>
  local old="$1" tok="$2" new before raw json reply
  new="$(mint_sid)"
  [ -n "$new" ] || { echo "rotation: could not mint a session id; keeping the old bus" >&2; return 1; }
  before="$(fingerprint "$HANDOFF_MD")"
  claude_call resume "$old" "$HANDOFF_TIMEOUT" "Read,Grep,Glob,Write,Edit" "$(handoff_prompt "$old" "$tok")" >/dev/null
  # An old BUS-HANDOFF.md from an earlier rotation must not count as this handoff.
  if [ ! -f "$HANDOFF_MD" ] || [ "$(fingerprint "$HANDOFF_MD")" = "$before" ]; then
    echo "rotation: BUS-HANDOFF.md was not (re)written; keeping the old bus" >&2; return 1
  fi
  raw="$(claude_call new "$new" "$HANDOFF_TIMEOUT" "Read,Grep,Glob" "$(seed_prompt "$old")")"
  json="$(result_json "$raw")"; reply="$(printf '%s' "$json" | jqr -r '.result // ""')"
  if ! call_ok "$json" "$reply" || ! printf '%s' "$reply" | grep -q 'BUS-READY'; then
    echo "rotation: the new bus did not answer BUS-READY; keeping the old bus ($(excerpt "$raw" 200))" >&2; return 1
  fi
  echo "$new" > "$BUS_SID_FILE"
  st_bump handovers >/dev/null
  append "" "### Bus rotated at $tok tokens ($(now))" "" \
         "- parent: \`$old\`" "- child: \`$new\`" \
         "- handoff: [BUS-HANDOFF.md](BUS-HANDOFF.md), memory: [BUS-MEMORY.md](BUS-MEMORY.md)"
  return 0
}

# --------------------------------------------------------------- subcommands ----
on_off() { if [ -f "$1" ]; then echo on; else echo off; fi; }
lock_owner() { if [ -e "$LOCK_PATH" ]; then printf 'taken by pid %s' "$(cat "$LOCK_PATH" 2>/dev/null)"; else printf 'free'; fi; }

cmd_status() {
  local sid g v n t ruled="" suspect="" open wakes need
  sid=""; [ -f "$BUS_SID_FILE" ] && sid="$(tr -d ' \r\n' < "$BUS_SID_FILE")"
  open="$(open_goal)"
  printf '%-10s %s\n' \
    pack     "$PACK_NAME ($PACK_PATH)" \
    latches  "relay $(on_off "$RELAY_FLAG"), gate $(on_off "$GATE_FLAG")" \
    sessions "bus ${sid:-(not seeded)}, worker $(st_get worker_sid | tr -d '\r')" \
    lock     "$(lock_owner)" \
    models   "bus $BUS_MODEL, worker $WORKER_MODEL" \
    context  "rotates at $ROTATE_TOKENS tokens, warns at $WARN_TOKENS; last reading $(st_get_or bus_tokens -); handovers $(st_get_or handovers 0)" \
    now      "${open:-every goal is judged}"
  [ -f "$PAUSE_FILE" ] && printf '%-10s %s\n' paused "after $(cat "$PAUSE_FILE") (planned); --next prints the next instructions"
  if [ -f "$REPO_ROOT/.claude/settings.local.json" ]; then
    need=$(( REVIEW_TIMEOUT + 2 * HANDOFF_TIMEOUT + 60 ))
    if t="$(settings_timeout_ok "$REPO_ROOT/.claude/settings.local.json")"; then
      printf '%-10s %s\n' settings "relay hook timeout $t s (ok)"
    else
      printf '%-10s %s\n' settings "⚠️ relay hook timeout $t s; it must exceed $need s"
    fi
  fi
  if [ ! -f "$STATE_PATH" ]; then
    # Before the first firing a full table only means a finished goal, not one that escaped review.
    printf '%-10s %s\n' rulings "(the hook has not fired yet, so missing reviews cannot be judged)"
  else
    for g in $GOAL_LIST; do
      v="$(st_get "ruled_$g")"
      if [ -z "$v" ]; then
        [ -f "$PROGRESS_MD" ] && [ "$(open_rows "$g" "$PROGRESS_MD")" = 0 ] && suspect="$suspect $g"
        continue
      fi
      n="$(st_get "rejects_all_$g")"
      [ "${n:-0}" != 0 ] && v="$v(rejected ${n}x)"
      ruled="$ruled $g:$v"
    done
    if [ -n "$ruled" ]; then printf '%-10s %s\n' rulings "${ruled# }"
    else printf '%-10s %s\n' rulings "(no goal has a ruling yet)"; fi
    if [ -n "$suspect" ]; then
      printf '%s\n' "⚠️ suspect:${suspect} — a full table without a ruling. Rule out, in this order:" \
        "    1) the worker has not printed the closing line yet (normal while it is still running)" \
        "    2) the worker stopped without a closing line, so the goal escaped review (an accident)" \
        "    3) it was reviewed but booked to another goal; only the prose of BUS-LOG.md can tell"
    fi
  fi
  wakes="$(st_get_or wakeups 0)"
  printf '%-10s %s\n' \
    cost  "\$$(st_get_or bus_cost_usd 0.0000) on the bus side as the CLI reports it (API-equivalent, not money spent); wake-ups $wakes; usage-limit stops $(st_get_or limit_stops 0)" \
    gate  "blocks in a row $(cat "$GATE_STREAK_FILE" 2>/dev/null || echo 0); blocked at goal boundaries in total $(st_get_or gate_blocks_all 0)"
  if [ -f "$PROGRESS_MD" ]; then
    for g in $GOAL_LIST; do printf '%s rows without a verdict: %s\n' "$g" "$(open_rows "$g" "$PROGRESS_MD")"; done
  fi
}

cmd_recover() { # cmd_recover [session-id]: print the last reply of a bus session from its transcript
  local want="${1:-}" file
  if [ -z "$want" ] && [ -f "$BUS_SID_FILE" ]; then want="$(tr -d ' \r\n' < "$BUS_SID_FILE")"; fi
  if [ -z "$want" ]; then
    echo "goal-bus --recover: no session id (.bus-sid is missing and none was given)" >&2; return 1
  fi
  file="$(transcript_for "$want")"
  if [ -z "$file" ]; then
    echo "goal-bus --recover: no transcript for $want under $(claude_home)/projects/" >&2; return 1
  fi
  final_reply_text "$file"
}

cmd_notify() {
  local body="${1:-}" sid raw json reply rc n
  if [ -z "$body" ] || [ "$body" = "-" ]; then body="$(cat 2>/dev/null || true)"; fi
  [ -n "$body" ] || { echo "goal-bus --notify: nothing to deliver (pass the text or pipe it in)" >&2; return 1; }
  [ -d "$PACK_DIR" ] || { echo "goal-bus --notify: task directory not found: $PACK_DIR" >&2; return 1; }
  [ -f "$BUS_SID_FILE" ] || { echo "goal-bus --notify: $BUS_SID_FILE is missing (seed the bus first)" >&2; return 1; }
  sid="$(tr -d ' \r\n' < "$BUS_SID_FILE")"
  [ -n "$sid" ] || { echo "goal-bus --notify: .bus-sid is empty" >&2; return 1; }
  lock_take || {
    echo "goal-bus --notify: the bus is being woken elsewhere (lock $(cat "$LOCK_PATH" 2>/dev/null)); gave up on purpose." >&2
    echo "  If you are sure nobody is running: goal-bus.sh --reset" >&2
    return 3; }
  trap 'rm -f "$LOCK_PATH"' EXIT
  raw="$(claude_call resume "$sid" "$REVIEW_TIMEOUT" "$REVIEW_TOOLS" "$body")"; rc=$?
  json="$(result_json "$raw")"; reply="$(printf '%s' "$json" | jqr -r '.result // ""')"
  if hit_usage_limit "$raw" "$json" "$reply"; then
    echo "goal-bus --notify: usage limit or rate limit; the bus was not woken and nothing was billed." >&2; return 4
  fi
  if [ "$rc" -ne 0 ] || [ -z "$reply" ]; then
    echo "goal-bus --notify: waking the bus failed (rc=$rc: $(excerpt "$raw" 200)). If it did answer, --recover prints the reply; do not pay twice." >&2
    return 5
  fi
  # Manual deliveries cost money and produce rulings too; bill them so the final numbers add up.
  n="$(st_bump wakeups)"
  st_put bus_tokens "$(tokens_for_sid "$sid")"
  st_put bus_cost_usd "$("$GB_AWK" -v a="$(st_get bus_cost_usd)" -v b="$(printf '%s' "$json" | jqr -r '.total_cost_usd // 0')" 'BEGIN { printf "%.4f", (a + 0) + (b + 0) }')"
  append "" "## Manual delivery — wake-up #$n ($(now))" "" "**Delivered by a human via \`--notify\`:**" ""
  printf '%s\n' "$body" | sed 's/^/> /' >> "$LEDGER_MD"
  append "" "**Bus reply:**" ""
  printf '%s\n' "$reply" >> "$LEDGER_MD"
  printf '%s\n' "$reply" | read_next_block > "$NEXT_STEP_FILE.tmp" && [ -s "$NEXT_STEP_FILE.tmp" ] && mv -f "$NEXT_STEP_FILE.tmp" "$NEXT_STEP_FILE" || rm -f "$NEXT_STEP_FILE.tmp"
  printf '%s\n' "$reply"
  [ "$n" -lt "$WAKE_LIMIT" ] || echo "goal-bus: wake-ups reached the cap ($WAKE_LIMIT); automatic reviews will now stop for a human." >&2
  return 0
}

cmd_seed() {
  local new raw json reply
  if [ -f "$BUS_SID_FILE" ] && [ "${1:-}" != "--force" ]; then
    echo "goal-bus --seed: $BUS_SID_FILE already exists ($(tr -d ' \r\n' < "$BUS_SID_FILE")). Use --seed --force to replace it." >&2
    return 1
  fi
  [ -f "$PACK_DIR/BUS-PROTOCOL.md" ] || { echo "goal-bus --seed: $PACK_PATH/BUS-PROTOCOL.md is missing; write the goal pack first." >&2; return 1; }
  new="$(mint_sid)"
  [ -n "$new" ] || { echo "goal-bus --seed: could not mint a session id" >&2; return 1; }
  raw="$(claude_call new "$new" "$HANDOFF_TIMEOUT" "Read,Grep,Glob" "$(seed_prompt)")"
  json="$(result_json "$raw")"; reply="$(printf '%s' "$json" | jqr -r '.result // ""')"
  if ! call_ok "$json" "$reply" || ! printf '%s' "$reply" | grep -q 'BUS-READY'; then
    echo "goal-bus --seed: the new session did not answer BUS-READY; nothing was recorded." >&2
    excerpt "$raw" 400 >&2; echo >&2
    return 1
  fi
  echo "$new" > "$BUS_SID_FILE"
  append "" "## Bus seeded ($(now))" "" "- session: \`$new\`" "- model: $BUS_MODEL"
  echo "$new"
}

cmd_next() {
  [ -s "$NEXT_STEP_FILE" ] || { echo "goal-bus --next: no saved instructions yet" >&2; return 1; }
  cat "$NEXT_STEP_FILE"
  local w; w="$(st_get worker_sid)"
  if [ -n "$w" ]; then
    { echo; echo "# to resume the worker with these instructions:"
      echo "#   bash .claude/hooks/bin/start-worker.sh --resume $w --file $PACK_PATH/.next-step"; } >&2
  fi
  return 0
}

case "${1:-}" in
  --selftest) exec bash "$HOOK_DIR/selftest/bus-tests.sh" ;;
  --status)   cmd_status; exit 0 ;;
  --notify)   shift; cmd_notify "$@"; exit $? ;;
  --seed)     shift; cmd_seed "$@"; exit $? ;;
  --next)     cmd_next; exit $? ;;
  --reset)
    rm -f "$STATE_PATH" "$LOCK_PATH" "$PAUSE_FILE"
    echo "cleared .relay-state, .relay-lock and .relay-paused (BUS-LOG.md and PROGRESS.md are untouched)."
    echo "Before re-running, make sure no code or document is left half-written."
    exit 0 ;;
  --recover)  shift; cmd_recover "$@"; exit $? ;;
  -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
  "") ;;
  *) echo "goal-bus: unknown option $1 (see --help)" >&2; exit 1 ;;
esac

# ------------------------------------------------------------------ the hook ----
hook_input="$(cat 2>/dev/null || true)"

[ -z "${GOALBUS_NESTED:-}" ] || exit 0      # a session started by this hook; its settings are inherited
[ -f "$RELAY_FLAG" ] || exit 0                    # not armed: a complete no-op
[ -f "$BUS_SID_FILE" ] || { sysmsg "armed, but $PACK_PATH/.bus-sid is missing. Run goal-bus.sh --seed first."; exit 0; }
BUS_SID="$(tr -d ' \r\n' < "$BUS_SID_FILE")"

# Two guards, or the hook drafts every session in the repository into the current goal.
# One jq call: line 1 is the session id, line 2 the transcript path, the rest the last message.
parsed="$(printf '%s' "$hook_input" | jqr -r '(.session_id // ""), (.transcript_path // ""), (.last_assistant_message // "")')"
this_sid="${parsed%%$'\n'*}"
rest=""; [[ "$parsed" == *$'\n'* ]] && rest="${parsed#*$'\n'}"
tp="${rest%%$'\n'*}"
last=""; [[ "$rest" == *$'\n'* ]] && last="${rest#*$'\n'}"
[ "$this_sid" != "$BUS_SID" ] || exit 0     # 1) never drive the bus itself
if [ -z "$last" ] && [ -n "$tp" ] && [ -f "$tp" ]; then last="$(final_reply_text "$tp")"; fi
[ -n "$last" ] || exit 0
SIG="$(signature_line "$last")"
[ -n "$SIG" ] || exit 0                    # 2) only a session that prints the progress line is a worker

[ -n "$this_sid" ] && st_put worker_sid "$this_sid"
[ -f "$PAUSE_FILE" ] && rm -f "$PAUSE_FILE"        # a worker turn ended, so a planned pause is over

boundary="$(line_kind "$SIG")"
forced=""
if [ -z "$boundary" ]; then
  # A goal whose table filled up without a boundary line would silently escape review; review it now.
  forced="$(unreviewed_goal)"
  [ -n "$forced" ] && boundary=COMPLETE
fi

# --- a turn inside a goal: the hook itself is the driver ---
# Text fed back through a Stop hook cannot start a /goal, so the relay continues goals by reading the
# file: the only way out is a table where every row has a verdict.
if [ -z "$boundary" ]; then
  cg="$(open_goal)"
  [ -n "$cg" ] || exit 0                   # every goal is judged: nothing to drive
  turns="$(st_bump "turns_in_$cg")"
  if [ "$turns" -ge "$TURN_LIMIT" ]; then
    sysmsg "$cg has used $turns turns without finishing (cap $TURN_LIMIT). Stopped for a human; see --status."
    exit 0
  fi
  left="$(open_rows "$cg" "$PROGRESS_MD")"
  {
    echo "Continue $cg: $left row(s) in the $cg section of PROGRESS.md have no verdict yet (turn $turns/$TURN_LIMIT)."
    echo "Judge the next row and write it to PROGRESS.md. When every row has a verdict, print: PROGRESS: $cg COMPLETE"
    echo "If you are blocked, print: PROGRESS: $cg BLOCKED <reason>   (goal name first, so the verdict is booked to $cg)"
    echo "End every turn on one of these lines. Ending on anything else wakes nobody and the chain stops silently."
  } >&2
  exit 2
fi

# --- a boundary ---
goal="${forced:-$(line_goal "$SIG")}"
goal="${goal:-$(open_goal)}"
goal="${goal:-G?}"

if [ "$boundary" = COMPLETE ] && [ -f "$PROGRESS_MD" ]; then
  left="$(open_rows "$goal" "$PROGRESS_MD")"
  if [ "${left:-0}" -gt 0 ]; then
    {
      echo "$goal was reported COMPLETE, but $left row(s) in its section of PROGRESS.md have no verdict. The bus was not woken."
      echo "Give every row a verdict ($VERDICT_WORDS; none may stay empty), then report COMPLETE again."
    } >&2
    exit 2
  fi
fi

lock_take || { sysmsg "the bus is being woken elsewhere (lock held by $(cat "$LOCK_PATH" 2>/dev/null)); skipped. If nobody is running: goal-bus.sh --reset"; exit 0; }
trap 'rm -f "$LOCK_PATH"' EXIT

# --- cheap checks first: the evidence gate answers in seconds and does not wake the bus ---
gate_note=""
if [ "$boundary" = COMPLETE ]; then
  gate_out="$(check_evidence "$PROGRESS_MD" "$PACK_PATH/PROGRESS.md" 2>/dev/null)"
  if [ -n "$gate_out" ]; then
    gb="$(st_bump gate_streak)"; st_bump gate_blocks_all >/dev/null
    if [ "$gb" -le "$GATE_BLOCK_LIMIT" ]; then
      {
        echo "The evidence gate did not pass ($gb/$GATE_BLOCK_LIMIT), so $goal cannot be reported complete yet. The bus was not woken:"
        echo "$gate_out"
        echo
        echo "Quote the actual observation, or downgrade the row to BLOCKED and say what is missing. Then report COMPLETE again."
      } >&2
      exit 2
    fi
    # Blocked to the cap: let the bus judge whether these findings can be fixed at all.
    st_put gate_streak 0
    gate_note="Note: the evidence gate blocked $GATE_BLOCK_LIMIT times in a row and has released this to you. Open findings:
$gate_out"
  else
    st_put gate_streak 0
  fi
fi

# --- cost brake: counts only real wake-ups, so it sits after the free checks ---
r="$(st_get wakeups)"; reviews=$(( ${r:-0} + 1 ))
if [ "$reviews" -gt "$WAKE_LIMIT" ]; then
  sysmsg "bus wake-ups reached the cap ($WAKE_LIMIT). Stopped for a human."
  exit 0
fi
st_put wakeups "$reviews"

if [ "$boundary" = BLOCKED ]; then headline="$goal reported BLOCKED."; else headline="$goal is complete."; fi
[ -n "$forced" ] && headline="$goal has a full judgment table, but the worker never printed its boundary line. Review it now; the verdict will be booked to $goal."
notify="$headline

(Delivered by the goal-bus Stop hook, not typed by a human. The worker's last message follows.)

--- worker's last message ---
${last:0:4000}
--- end ---
${gate_note}

Review it as $PACK_PATH/BUS-PROTOCOL.md says and end your reply with the BUS-VERDICT block."

raw="$(claude_call resume "$BUS_SID" "$REVIEW_TIMEOUT" "$REVIEW_TOOLS" "$notify")"; rc=$?
json="$(result_json "$raw")"
reply="$(printf '%s' "$json" | jqr -r '.result // ""')"
ctx="$(tokens_for_sid "$BUS_SID")"
cost="$(printf '%s' "$json" | jqr -r '.total_cost_usd // 0')"

# A usage limit is not an ordinary failure: retrying at once only burns the cap. Refund and stop.
if hit_usage_limit "$raw" "$json" "$reply"; then
  st_put wakeups "$(( reviews - 1 ))"; st_bump limit_stops >/dev/null
  append "" "## $goal — wake-up stopped by a usage or rate limit ($(now))" "" \
         "Output excerpt: \`$(excerpt "$raw" 300)\`" "" \
         "The counter was refunded. After the limit resets, tell the worker to continue; the current goal is derived from PROGRESS.md." \
         "If you suspect the review actually finished, recover it with \`goal-bus.sh --recover\` instead of paying for it again."
  sysmsg "usage or rate limit: the bus was not woken (counter refunded). Tell the worker to continue after the reset. Details in BUS-LOG.md."
  exit 0
fi
if [ "$rc" -ne 0 ] || [ -z "$reply" ]; then
  st_put wakeups "$(( reviews - 1 ))"
  # Say why in the ledger: "rc=1" alone sent the toy run's operator into the transcripts.
  why="$(excerpt "$raw" 300)"; hint=""
  if printf '%s' "$why" | grep -qiE "$AUTH_RE"; then
    hint="The CLI inside the hook had no credential (a hook may not receive the CLI's own token); point GOALBUS_ENV_FILE at a file that restores it, see bus.config.sh."
  fi
  append "" "## $goal — waking the bus failed ($(now))" "" \
         "rc=$rc. Output excerpt: \`${why:-(no output)}\`" "" \
         "${hint:+$hint }The counter was refunded and $goal was not reviewed. If the bus did answer, \`goal-bus.sh --recover\` prints its last reply."
  sysmsg "waking the bus failed (rc=$rc: ${why:0:120}); $goal was not reviewed and the counter was refunded.${hint:+ $hint} Details in BUS-LOG.md; if the bus did answer, goal-bus.sh --recover prints its last reply."
  exit 0
fi
st_put bus_tokens "$ctx"
st_put bus_cost_usd "$("$GB_AWK" -v a="$(st_get bus_cost_usd)" -v b="$cost" 'BEGIN { printf "%.4f", (a + 0) + (b + 0) }')"

ruling="$(printf '%s\n' "$reply" | read_verdict)"
steps="$(printf '%s\n' "$reply" | read_next_block)"
if [ -z "$steps" ]; then   # no BUS-NEXT block: pass on the end of the reply rather than nothing
  if [ "${#reply}" -gt 3000 ]; then steps="${reply: -3000}"; else steps="$reply"; fi
fi

append "" "## $goal — review #$reviews ($(now))" "" "**Verdict: ${ruling:-UNPARSED}** (bus context: $ctx tokens)" ""
printf '%s\n' "$steps" >> "$LEDGER_MD"
if [ "$ctx" = 0 ]; then
  append "" "> ⚠️ The bus transcript could not be read, so its context is unknown (logged as 0). Rotation can never fire in this state; check that the transcript of \`$BUS_SID\` exists."
elif [ "$ctx" -gt "$WARN_TOKENS" ] 2>/dev/null && [ "$ctx" -le "$ROTATE_TOKENS" ] 2>/dev/null; then
  append "" "> ⚠️ Bus context is $ctx tokens (warn $WARN_TOKENS, rotate $ROTATE_TOKENS). If review quality drops from here, lower ROTATE_TOKENS."
fi
# BUS-LOG keeps the instructions; the reasoning behind a verdict would otherwise be lost, and the
# human audit for rubber-stamping needs exactly that. Keep the whole reply in a side file.
{
  echo; echo "## $goal — review #$reviews, full reply ($(now))"; echo
  printf '%s\n' "$reply"
} >> "$REVIEWS_MD"
[ -n "$ruling" ] && st_put "ruled_$goal" "$ruling"

case "$ruling" in
  REJECT)
    streak="$(st_bump "rejects_streak_$goal")"; st_bump "rejects_all_$goal" >/dev/null
    if [ "$streak" -ge "$REJECT_LIMIT" ]; then
      sysmsg "the bus rejected $goal $streak times in a row (cap $REJECT_LIMIT). Stopped for a human; see BUS-LOG.md."
      exit 0
    fi
    { echo "The bus rejected $goal ($streak/$REJECT_LIMIT):"; echo; printf '%s\n' "$steps"; } >&2
    exit 2 ;;
  PASS)
    st_put "rejects_streak_$goal" 0
    printf '%s\n' "$steps" > "$NEXT_STEP_FILE"
    rot_note=""
    if [ "$ctx" -gt "$ROTATE_TOKENS" ] 2>/dev/null; then
      if hand_over_bus "$BUS_SID" "$ctx"; then rot_note="(The bus was rotated at $ctx tokens; see BUS-LOG.md.)"
      else rot_note="(The bus is at $ctx tokens but rotation failed; the old session continues. Watch the review quality.)"; fi
    fi
    if in_list "$goal" "$PAUSE_AFTER"; then
      echo "$goal ($(now))" > "$PAUSE_FILE"
      sysmsg "paused after $goal as planned (PAUSE_AFTER). The next instructions are saved; print them with goal-bus.sh --next. $rot_note"
      exit 0
    fi
    { echo "The bus reviewed $goal: PASS. The next instructions follow; carry them out."; [ -n "$rot_note" ] && echo "$rot_note"; echo; printf '%s\n' "$steps"; } >&2
    exit 2 ;;
  ESCALATE)
    printf '%s\n' "$steps" > "$NEXT_STEP_FILE"
    sysmsg "the bus escalated $goal to you. Read $PACK_PATH/BUS-LOG.md and answer with goal-bus.sh --notify."
    exit 0 ;;
  DONE)
    sysmsg "the bus judged every goal done. See $PACK_PATH/BUS-LOG.md."
    exit 0 ;;
  *)
    sysmsg "no parsable BUS-VERDICT in the bus reply; it was logged as is and the relay stopped. goal-bus.sh --recover prints the raw reply."
    exit 0 ;;
esac
