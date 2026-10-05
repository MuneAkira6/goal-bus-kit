#!/usr/bin/env bash
# start-worker.sh — start or resume the worker, the session the hooks drive.
#
#   start-worker.sh [--detach] --file <instructions.md>                   start a new worker
#   start-worker.sh [--detach] --resume <session-id> --file <file>        continue an existing worker
#   start-worker.sh [--detach] [--resume <id>] "<instructions>"           instructions inline
#
# The worker runs headless (claude -p). Its Stop hooks keep it going goal after goal, and the
# process ends when the relay stops (DONE, ESCALATE, a cap, a planned pause or an anomaly).
# Output is appended to <task-dir>/.worker-output; a new session id goes to <task-dir>/.worker-sid.
# --detach starts it in the background with nohup and prints the process id.

set -uo pipefail
BIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOOK_DIR="$(cd "$BIN_DIR/.." && pwd)"
. "$HOOK_DIR/bus.config.sh"
. "$HOOK_DIR/lib/common.sh"
gb_paths

die() { echo "start-worker: $*" >&2; exit 1; }
detach="" resume="" text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --detach) detach=1; shift ;;
    --resume) resume="${2:-}"; [ -n "$resume" ] || die "--resume needs a session id"; shift 2 ;;
    --file)   [ -f "${2:-}" ] || die "no such file: ${2:-}"; text="$(cat "$2")"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) text="$1"; shift ;;
  esac
done
[ -n "$text" ] || die "no instructions given (use --file or pass them as an argument)"
[ -f "$BUS_SID_FILE" ] || die "$PACK_PATH/.bus-sid is missing; seed the bus first (goal-bus.sh --seed)"
[ -f "$RELAY_FLAG" ] || echo "start-worker: warning: $PACK_PATH/.relay-on is missing, so the relay will not drive this worker" >&2

# The only place a worker is started. Unlike claude_call it must NOT set GOALBUS_NESTED: the worker is
# exactly the session the hooks exist to drive.
worker_call() { # worker_call <new|resume> <session-id> <instructions>
  local flag
  case "$1" in new) flag=--session-id ;; resume) flag=--resume ;; *) return 64 ;; esac
  env -u GOALBUS_NESTED claude "$flag" "$2" -p "$3" --model "$WORKER_MODEL" \
    --permission-mode bypassPermissions --output-format json < /dev/null
}

if [ -n "$resume" ]; then mode=resume; sid="$resume"
else
  mode=new; sid="$(mint_sid)"
  [ -n "$sid" ] || die "could not mint a session id"
  echo "$sid" > "$PACK_DIR/.worker-sid"
fi
st_put worker_sid "$sid"
log="$PACK_DIR/.worker-output"
echo "=== $(now) $mode worker $sid (model $WORKER_MODEL)" >> "$log"
echo "worker $sid ($mode); output goes to $PACK_PATH/.worker-output"
if [ -n "$detach" ]; then
  WORKER_MODEL="$WORKER_MODEL" nohup bash -c "$(declare -f worker_call); worker_call \"\$@\"" _ "$mode" "$sid" "$text" >> "$log" 2>&1 &
  echo "detached: pid $!"
else
  worker_call "$mode" "$sid" "$text" >> "$log" 2>&1
  rc=$?
  echo "worker exited with status $rc; the last lines of the log:"
  tail -n 5 "$log"
  exit "$rc"
fi
