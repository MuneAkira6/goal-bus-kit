#!/usr/bin/env bash
# watch.sh — watch a running relay through its artifacts only.
#
#   watch.sh [poll-seconds=120] [stall-polls=15]   print one line per event until the worker ends
#   watch.sh --once                                print what changed since the previous --once
#
# It never searches a transcript for protocol text. The goal pack spells out the protocol lines (it
# has to, to teach the worker) and the worker reads them in its first turn, so a text search finds
# documentation, not events. Instead it asks the hook's own parser (goal-bus.sh --status) and watches
# quantities that only grow when work happens: the worker transcript, PROGRESS.md, BUS-LOG.md and
# BUS-REVIEWS.md. Stale leftovers add a constant, and a constant has no delta, so they cannot pin it.

set -uo pipefail
BIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$(cd "$BIN_DIR/.." && pwd)"
. "$HOOK_DIR/bus.config.sh"
. "$HOOK_DIR/lib/common.sh"
gb_paths

SNAP="$PACK_DIR/.watch-state"
size() { if [ -f "$1" ]; then wc -c < "$1" | tr -d ' \r\n'; else echo 0; fi; }
# st_get/st_put read STATE through bash's dynamic scoping, so a local STATE points them at the snapshot.
# shellcheck disable=SC2034
snap_get() { local STATE_PATH="$SNAP"; st_get "$1"; }
# shellcheck disable=SC2034
snap_set() { local STATE_PATH="$SNAP"; st_put "$1" "$2"; }

# What the worker's last words say about why it stopped (the three stall kinds need three responses).
classify_stop() {
  local tail_txt
  tail_txt="$(tail -n 20 "$PACK_DIR/.worker-output" 2>/dev/null)"
  case "$tail_txt" in
    *[Oo]verloaded*|*" 529"*|*"API Error: 5"*) echo "overloaded: safe to resume a limited number of times" ;;
    *"usage limit"*|*"rate limit"*|*" 429"*)   echo "usage limit: wait for the reset, do not retry in a loop" ;;
    *) echo "voluntary stop or a hook decision: read --status and the last BUS-LOG entry before resuming" ;;
  esac
}

# Prints how many result lines the worker log holds, and succeeds only if one follows the last header.
worker_finished() {
  "$GB_AWK" '/^=== /{after=0} /"type":"result"/{after=1; n++} END{if (after) print n; exit !after}' \
    "$PACK_DIR/.worker-output" 2>/dev/null
}

once() {
  local left prev wsid tr t_size p_size l_size r_size gate changed=0 static runs
  left="$(bash "$HOOK_DIR/goal-bus.sh" --status 2>/dev/null \
    | sed -n 's/^\(G[0-9a-z]*\) rows without a verdict: \([0-9]*\)$/\1=\2/p' | tr '\n' ' ' | sed 's/ *$//')"
  prev="$(snap_get rows_left)"
  if [ -n "$left" ] && [ "$left" != "$prev" ]; then
    [ -n "$prev" ] && echo "[progress] $left (was: $prev)"
    snap_set rows_left "$left"; changed=1
  fi

  l_size="$(size "$LEDGER_MD")"
  if [ "$l_size" != "$(snap_get log)" ]; then
    [ -n "$(snap_get log)" ] && echo "[bus] $(grep -E '^## |^\*\*Verdict: ' "$LEDGER_MD" | tail -n 2 | tr '\n' ' ')"
    snap_set log "$l_size"; changed=1
  fi
  r_size="$(size "$REVIEWS_MD")"
  if [ "$r_size" != "$(snap_get wakeups)" ]; then
    [ -n "$(snap_get wakeups)" ] && echo "[review] BUS-REVIEWS.md grew to $r_size bytes (the full text of the latest review)"
    snap_set wakeups "$r_size"; changed=1
  fi
  gate="$(cat "$GATE_STREAK_FILE" 2>/dev/null | tr -d ' \r\n')"; gate="${gate:-0}"
  if [ "$gate" != "$(snap_get gate)" ]; then [ -n "$(snap_get gate)" ] && echo "[gate] consecutive evidence-gate blocks: $gate"; snap_set gate "$gate"; fi
  if [ -f "$PAUSE_FILE" ] && [ "$(snap_get paused)" != yes ]; then echo "[paused] after $(cat "$PAUSE_FILE"); print the next instructions with goal-bus.sh --next"; snap_set paused yes; fi
  [ -f "$PAUSE_FILE" ] || snap_set paused no

  p_size="$(size "$PROGRESS_MD")"
  [ "$p_size" != "$(snap_get progress)" ] && { snap_set progress "$p_size"; changed=1; }
  wsid="$(tr -d ' \r\n' < "$PACK_DIR/.worker-sid" 2>/dev/null)"
  tr="$( [ -n "$wsid" ] && transcript_for "$wsid")"
  t_size="$( [ -n "$tr" ] && size "$tr" || echo 0)"
  [ "$t_size" != "$(snap_get transcript)" ] && { snap_set transcript "$t_size"; changed=1; }

  # start-worker writes a "=== " header before every start or resume, and the CLI's result line lands
  # when that process ends. Only a result after the last header means "finished": the result of the
  # run before a --resume is still in the log (the toy run on the host tripped over this).
  if runs="$(worker_finished)" && [ "$(snap_get ended)" != "$runs" ]; then
    echo "[ended] the worker process finished. Last verdict: $(grep -E '^\*\*Verdict: ' "$LEDGER_MD" 2>/dev/null | tail -n 1). $(classify_stop)"
    [ -n "$wsid" ] && echo "        resume: bash .claude/hooks/bin/start-worker.sh --resume $wsid \"<corrective instruction>\""
    snap_set ended "$runs"
    return 10
  fi
  if [ "$changed" = 1 ]; then snap_set static 0
  else
    static=$(( $(snap_get static || echo 0) + 1 )); snap_set static "$static"
    [ "$static" -eq "${STALL_POLLS:-15}" ] && echo "[stall?] nothing has grown for $static polls. $(classify_stop)"
  fi
  return 0
}

case "${1:-}" in
  --once) once; rc=$?; [ "$rc" = 10 ] && exit 0; exit "$rc" ;;
  -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
esac
POLL_SECS="${1:-120}"; STALL_POLLS="${2:-15}"
echo "watching $PACK_PATH every ${POLL_SECS}s (stall after $STALL_POLLS quiet polls)"
while true; do
  once; [ $? = 10 ] && exit 0
  sleep "$POLL_SECS"
done
