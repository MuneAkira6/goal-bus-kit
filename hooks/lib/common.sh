# shellcheck shell=bash
# shellcheck disable=SC2034  # the paths and constants defined here are used by the scripts that source this file
# common.sh — shared by goal-bus.sh, evidence-gate.sh, bin/*.sh and the selftests.
# Every function that recognises a protocol line or reads a table lives here, so the hook path and
# the selftest exercise the same code and cannot drift apart.
# Sourcing file must define HOOK_DIR and have sourced bus.config.sh.

GB_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GB_AWK="${GOALBUS_AWK:-awk}"

# ---------------------------------------------------------------- paths ----
gb_paths() {
  REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$HOOK_DIR/../.." && pwd)}"
  PACK_DIR="$REPO_ROOT/$PACK_PATH"
  PROGRESS_MD="$PACK_DIR/PROGRESS.md"
  RELAY_FLAG="$PACK_DIR/.relay-on";          GATE_FLAG="$PACK_DIR/.gate-on"
  BUS_SID_FILE="$PACK_DIR/.bus-sid"; STATE_PATH="$PACK_DIR/.relay-state"; LOCK_PATH="$PACK_DIR/.relay-lock"
  NEXT_STEP_FILE="$PACK_DIR/.next-step";     PAUSE_FILE="$PACK_DIR/.relay-paused"; GATE_STREAK_FILE="$PACK_DIR/.gate-streak"
  LEDGER_MD="$PACK_DIR/BUS-LOG.md";          REVIEWS_MD="$PACK_DIR/BUS-REVIEWS.md"
  MEMORY_MD="$PACK_DIR/BUS-MEMORY.md";    HANDOFF_MD="$PACK_DIR/BUS-HANDOFF.md"
  GATE_SH="$HOOK_DIR/evidence-gate.sh"
}

now() { printf '%(%F %T)T' -1; }

# jq on Windows writes CRLF; every text result goes through this.
jqr() { jq "$@" 2>/dev/null | tr -d '\r'; }

# A systemMessage for the human; the hook then lets the turn end.
sysmsg() { jq -cn --arg m "goal-bus: $1" '{systemMessage: $m}' 2>/dev/null | tr -d '\r' || printf '{"systemMessage":"goal-bus"}\n'; }

in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

# ------------------------------------------------------ protocol lines ----
# Goal names are a mechanism constant: G<number> with an optional one-letter suffix.
GOAL_NAME_RE='G[0-9]+[a-z]?'
CLOSE_DONE_RE="PROGRESS: *${GOAL_NAME_RE} +COMPLETE"
CLOSE_BLOCKED_RE="PROGRESS: *((${GOAL_NAME_RE}) +)?BLOCKED"
# The worker's signature: a line that IS a progress line (leading markdown decoration allowed),
# not a line that merely mentions the prefix. A bare substring once drafted the bus as a worker.
WORKER_LINE_RE="^[[:space:]>*_-]*PROGRESS: *(${GOAL_NAME_RE}|BLOCKED)([[:space:]*_]|\$)"
VERDICT_PREFIX_RE='^[ *_#>-]*BUS-VERDICT:[ *_]*'
VERDICT_WORDS="PASS${CITE_VERDICT:+/${CITE_VERDICT}}/FAIL/BLOCKED/DEFERRED"

# The last signature line of a message decides what the turn was: the protocol says a turn ends on
# its progress or boundary line, and an earlier line may just quote another goal.
signature_line() {
  local line found=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ $WORKER_LINE_RE ]] && found="$line"
  done <<< "$1"
  printf '%s' "$found"
}
has_signature() { [ -n "$(signature_line "$1")" ]; }

line_kind() { # line_kind <signature-line> -> COMPLETE | BLOCKED | (empty)
  [ -n "$1" ] || return 0
  if [[ "$1" =~ $CLOSE_BLOCKED_RE ]]; then echo BLOCKED
  elif [[ "$1" =~ $CLOSE_DONE_RE ]]; then echo COMPLETE
  fi
  return 0
}
line_goal() { # line_goal <signature-line> -> the goal it names (may be empty)
  if [[ "$1" =~ PROGRESS:\ *(G[0-9]+[a-z]?) ]]; then printf '%s' "${BASH_REMATCH[1]}"
  # "PROGRESS: BLOCKED G5 <reason>" puts the name after the keyword; accept it rather than fall back
  # to guessing, because a guess lands on the next goal whenever this goal's table is already full.
  elif [[ "$1" =~ BLOCKED\ +(G[0-9]+[a-z]?) ]]; then printf '%s' "${BASH_REMATCH[1]}"
  fi
  return 0
}
closing_kind() { line_kind "$(signature_line "$1")"; }   # closing_kind <message>
closing_goal() { line_goal "$(signature_line "$1")"; }   # closing_goal <message>

# The bus ends its reply with "BUS-VERDICT: X" and a BUS-NEXT block. Real replies decorate them
# (bold, list or quote prefixes), and a reply may quote a verdict line while explaining something,
# so take the LAST one: taking the first can turn an explanation into a false PASS, while taking the
# last can at worst yield nothing, which stops the relay for a human.
read_verdict() { # reads the reply on stdin
  local line v="" re="${VERDICT_PREFIX_RE}([A-Z]+)"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ $re ]] && v="${BASH_REMATCH[1]}"
  done
  printf '%s' "$v"
}
read_next_block() { # reads the reply on stdin; prints the last BUS-NEXT block
  local line buf="" last="" inb=0 have=0
  local b='^[ *_#>-]*BUS-NEXT-BEGIN[ *_]*$' e='^[ *_#>-]*BUS-NEXT-END[ *_]*$'
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [[ "$line" =~ $b ]]; then buf=""; inb=1; continue; fi
    if [[ "$line" =~ $e ]]; then [ "$inb" = 1 ] && { last="$buf"; have=1; }; inb=0; continue; fi
    [ "$inb" = 1 ] && buf="$buf$line"$'\n'
  done
  [ "$have" = 1 ] && printf '%s' "$last"
  return 0
}

# ---------------------------------------------------------------- state ----
# Plain bash, no child processes: the hook runs at the end of every turn, and on Windows each
# process spawn costs tens of milliseconds.
st_get() { # st_get <key> -> value (the last assignment wins)
  local line r=""
  [ -f "$STATE_PATH" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [ "${line%%=*}" = "$1" ] && r="${line#*=}"
  done < "$STATE_PATH"
  printf '%s' "$r"
}
st_put() { # st_put <key> <value>
  local line out=""
  if [ -f "$STATE_PATH" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [ "${line%%=*}" = "$1" ] || out="$out$line"$'\n'
    done < "$STATE_PATH"
  fi
  printf '%s%s=%s\n' "$out" "$1" "$2" > "$STATE_PATH"
}
st_bump() { local n; n="$(st_get "$1")"; n=$(( ${n:-0} + ${2:-1} )); st_put "$1" "$n"; printf '%s' "$n"; }
st_get_or() { local v; v="$(st_get "$1")"; printf %s "${v:-$2}"; }   # st_get_or <key> <default>

# Two sessions (or the hook and a human) waking the same bus would corrupt it: take it or give up.
lock_take() { ( set -o noclobber; echo "$$" > "$LOCK_PATH" ) 2>/dev/null; }

# --------------------------------------------------------------- tables ----
tables() { # tables <count|countall|check> <file> [goal] [label]
  local -a opts=(
    -v OP="$1" -v GOAL="${3:-}" -v SRC="${4:-$2}"
    -v VCOL_NAME="$VERDICT_HEADER" -v ECOL_NAME="$EVIDENCE_HEADER"
    -v CITE="$CITE_VERDICT" -v MARK_A="$CITE_MARK_A" -v MARK_B="$CITE_MARK_B"
    -v BANNED="$BANNED_VERDICTS" -v HEDGES="$WEASEL_WORDS"
    -v EXP_WORD="$FAIL_EXPECTED_WORD" -v ACT_WORD="$FAIL_ACTUAL_WORD" -v WAIT_HINT="$WAITS_FOR_HINT"
  )
  "$GB_AWK" "${opts[@]}" -f "$GB_LIB_DIR/tables.awk" "$2"
}
open_rows() { local n; n="$(tables count "$2" "$1" 2>/dev/null)"; printf '%s' "${n:-0}"; }   # open_rows <goal> <file>
check_evidence() { tables check "$1" "" "${2:-$1}"; }                                         # check_evidence <file> [label]
# All goals in one pass: lines "<goal> <empty-verdicts>"; lookup_count reads them without a child process.
goal_counts() { tables countall "$1" 2>/dev/null; }
lookup_count() { # lookup_count <goal> <goal_counts output>
  local g n
  while read -r g n; do [ "$g" = "$1" ] && { printf '%s' "${n:-0}"; return 0; }; done <<< "$2"
  printf 0
}

# The goal being worked on is read from the table every time, never stored: the first goal of
# GOAL_LIST that still has a row without a verdict. A crash, a quota stop or a hand edit of the table
# therefore cannot leave it pointing at the wrong goal.
open_goal() {
  [ -f "$PROGRESS_MD" ] || return 0
  local counts g
  counts="$(goal_counts "$PROGRESS_MD")"
  for g in $GOAL_LIST; do
    if [ "$(lookup_count "$g" "$counts")" != 0 ]; then printf '%s\n' "$g"; break; fi
  done
  return 0
}

# A goal whose rows are all judged but which never got a ruling: the worker filled its table and went
# on without the closing line, so open_goal() moved past it and nobody reviewed it. Asked only once
# some goal has a ruling, because before the first review a full table is simply a finished goal.
unreviewed_goal() {
  [ -f "$PROGRESS_MD" ] && [ -f "$STATE_PATH" ] || return 0
  local counts g ruled=""
  for g in $GOAL_LIST; do [ -z "$(st_get "ruled_$g")" ] || ruled=yes; done
  [ -n "$ruled" ] || return 0
  counts="$(goal_counts "$PROGRESS_MD")"
  for g in $GOAL_LIST; do
    [ -z "$(st_get "ruled_$g")" ] || continue
    # the first goal without a ruling decides: report it only if its table is already full
    [ "$(lookup_count "$g" "$counts")" = 0 ] && printf '%s\n' "$g"
    return 0
  done
  return 0
}

# ---------------------------------------------------------- transcripts ----
claude_home() { printf '%s' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }
transcript_for() {
  local f
  for f in "$(claude_home)"/projects/*/"$1".jsonl; do [ -f "$f" ] && { printf '%s' "$f"; return 0; }; done
  return 0
}

# The context in use is the usage of the LAST entry that has one (input + cache read + cache
# creation). The usage in a headless result is summed over every turn of the run and reads about ten
# times too high. Anything unreadable gives 0, which the ledger then reports loudly.
tokens_in_transcript() {
  local n
  n="$(tail -n 400 "$1" 2>/dev/null | jq -nR '
        [inputs | try fromjson catch null | objects | .message.usage? | objects]
        | (last // {}) as $u
        | ($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0)' \
      2>/dev/null | tr -d '\r')"
  if [[ "$n" =~ ^[0-9]+$ ]]; then printf '%s\n' "$n"; else echo 0; fi
}
tokens_for_sid() { local f; f="$(transcript_for "$1")"; [ -n "$f" ] && tokens_in_transcript "$f" || echo 0; }

# The text of the last assistant entry that has any. A verdict lost on the way back can be read from
# here instead of paying for the review a second time.
final_reply_text() {
  tail -n 400 "$1" 2>/dev/null | jq -nrR '
      [inputs | try fromjson catch null | objects | select(.type? == "assistant")
       | [.message.content[]? | objects | select(.type == "text") | .text | strings] | join("\n")
       | select(. != "")]
      | last // ""' 2>/dev/null | tr -d '\r'
}

# ------------------------------------------------------ result handling ----
# The CLI prints one JSON line; stderr (merged into the same capture) may surround it.
result_json() {
  local line found=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*\{ ]] && found="$line"
  done <<< "$1"
  printf '%s' "$found"
}

# Did the call return a complete reply? Compare is_error explicitly: jq's "//" treats false as
# missing, so `.is_error // true` would turn every success into a failure.
call_ok() { # call_ok <json> <reply>
  local ie
  ie="$(printf '%s' "$1" | jqr -r 'if .is_error == false then "ok" else "no" end' | head -n 1)"
  [ "$ie" = ok ] && [ -n "$2" ]
}
# "429" only as a word of its own: a bare 429 also matches inside session ids and costs (…-4291-…, 0.1429).
LIMIT_RE='usage limit|rate.?limit|(^|[^0-9A-Za-z])429([^0-9A-Za-z]|$)|quota|resets? at|too many requests'
# Should this be treated as hitting a usage limit? Success is judged FIRST: a quota notice on
# stderr can follow a review that completed and was paid for, and discarding it loses the verdict.
hit_usage_limit() { # hit_usage_limit <raw> <json> <reply>
  call_ok "$2" "$3" && return 1
  printf '%s' "$1" | grep -qiE "$LIMIT_RE"
}

# One line of CLI output for a ledger that may be published: line breaks folded, credentials inside
# URLs and anything shaped like an Anthropic token masked, cut in bash (no early-exiting reader, so
# no SIGPIPE).
excerpt() { # excerpt <text> [max-chars]
  local s
  s="$(printf '%s' "$1" | tr '\r\n' '  ' | sed -E -e 's#(://)[^/@ ]+@#\1***@#g' -e 's#sk-ant-[A-Za-z0-9_-]+#sk-ant-***#g')"
  printf '%s' "${s:0:${2:-300}}"
}
AUTH_RE='not logged in|/login|authentication_failed|authentication_error|invalid api key|invalid bearer token|oauth'

mint_sid() {
  local u=""
  [ -r /proc/sys/kernel/random/uuid ] && u="$(cat /proc/sys/kernel/random/uuid 2>/dev/null)"
  [ -n "$u" ] || u="$(uuidgen 2>/dev/null)"
  [ -n "$u" ] || u="$(python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null)"
  [ -n "$u" ] || u="$(python -c 'import uuid; print(uuid.uuid4())' 2>/dev/null)"
  [ -n "$u" ] || u="$(powershell -NoProfile -Command '[guid]::NewGuid().ToString()' 2>/dev/null)"
  printf '%s' "$u" | tr -d ' \r\n' | tr 'A-F' 'a-f'
}

# fingerprint <file> -> changes whenever the content changes ("none" when absent)
fingerprint() { if [ -f "$1" ]; then cksum < "$1" | tr -d ' \r\n'; else echo none; fi; }

# -------------------------------------------------------- the bus call ----
# The ONLY place a bus session is invoked: automatic reviews, handoffs, seeding and --notify all
# come through here. Retyping this command by hand tends to drop one of three pieces, and each
# omission fails silently:
#   GOALBUS_NESTED=1  keeps the bus's own Stop hooks from driving the bus
#   --allowedTools   a headless run denies every tool that is not listed
#   < /dev/null      otherwise the CLI waits for stdin
claude_call() { # claude_call <resume|new> <session-id> <timeout> <tools> <prompt>
  local flag
  case "$1" in resume) flag=--resume ;; new) flag=--session-id ;; *) return 64 ;; esac
  (
    # an optional file with environment the CLI needs (a proxy, for example), chosen by the operator
    # shellcheck source=/dev/null
    if [ -n "${GOALBUS_ENV_FILE:-}" ] && [ -f "$GOALBUS_ENV_FILE" ]; then . "$GOALBUS_ENV_FILE"; fi
    timeout "$3" env GOALBUS_NESTED=1 claude "$flag" "$2" -p "$5" \
      --model "$BUS_MODEL" --output-format json --allowedTools "$4" 2>&1 < /dev/null
  )
}

# --------------------------------------------------------------- prompts ----
seed_prompt() { # seed_prompt [parent-session]
  local intro="You are the long-lived bus for ${PACK_NAME}."
  [ -n "${1:-}" ] && intro="$intro You take over from session $1 (context rotation)."
  cat <<EOF
$intro
Read these files in order, then reply with the single line BUS-READY:
1. ${PACK_PATH}/BUS-HANDOFF.md, if it exists (your predecessor's handoff; read it first)
2. ${PACK_PATH}/BUS-PROTOCOL.md (your rules and the BUS-VERDICT contract)
3. ${PACK_PATH}/BUS-MEMORY.md (long-lived facts)
4. ${PACK_PATH}/SCOPE.md and ${PACK_PATH}/runbook.md, if they exist
5. ${PACK_PATH}/PROGRESS.md, and the two most recent reviews in ${PACK_PATH}/BUS-LOG.md
From the next "<goal> is complete." notification on, you are the bus. Do not start any other work now.
EOF
}

handoff_prompt() { # handoff_prompt <old-session> <tokens>
  cat <<EOF
Your context has reached $2 tokens and you are being rotated. Write ${PACK_PATH}/BUS-HANDOFF.md for your successor:
(1) lineage: parent session = $1, reason = context rotation;
(2) which goal the run is on and what happens next;
(3) the judgments that live only in your head and are not yet in BUS-LOG, PROGRESS or BUS-MEMORY:
    what you are watching, which conclusions you still doubt, which worker claims must be re-checked
    later. This part matters most; your successor can read everything else from the files.
Also merge long-lived facts into ${PACK_PATH}/BUS-MEMORY.md.
Write only these two files, then reply with the single line HANDOFF-WRITTEN.
EOF
}

# settings_timeout_ok <settings.json> -> prints the configured goal-bus hook timeout and returns
# non-zero when it cannot cover a review plus a rotation.
settings_timeout_ok() {
  local t need
  need=$(( REVIEW_TIMEOUT + 2 * HANDOFF_TIMEOUT + 60 ))
  t="$(jqr -r '[.hooks.Stop[]?.hooks[]? | select(.command | test("goal-bus")) | .timeout] | first // empty' "$1")"
  printf '%s' "${t:-missing}"
  [ -n "$t" ] && [ "$t" -gt "$need" ] 2>/dev/null
}
