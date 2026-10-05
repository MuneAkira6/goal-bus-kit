#!/usr/bin/env bash
# evidence-gate.sh — Stop hook that will not let a turn end while PROGRESS.md holds a verdict
# without the evidence the rules ask for.
#
# The /goal evaluator is a small model that reads the conversation only: it cannot open PROGRESS.md
# and cannot catch an invented quotation. This script reads the file.
#
# Stop-hook contract: exit 0 lets the turn end; exit 2 blocks it and feeds stderr back to the model.
# Off by default; it acts only while <task-dir>/.gate-on exists (parameters: bus.config.sh).
#   --check      print violations regardless of the latch; exit 1 when there is any (used by goal-bus.sh)
#   --selftest   run the gate's selftests
#
# It checks only what must hold at every moment. Conditions that become true at the end of a goal
# (environment restored, artifacts rebuilt) belong to the goal's definition of done, not here.

set -uo pipefail

HOOK_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$HOOK_DIR/bus.config.sh" ] || [ ! -f "$HOOK_DIR/lib/common.sh" ]; then
  case "${1:-}" in -*) echo "evidence-gate: bus.config.sh or lib/ is missing next to $0 (copy the whole hooks/ directory)" >&2; exit 1 ;; esac
  exit 0
fi
. "$HOOK_DIR/bus.config.sh"
. "$HOOK_DIR/lib/common.sh"
gb_paths

case "${1:-}" in
  --check)
    [ -f "$PROGRESS_MD" ] || exit 0
    check_evidence "$PROGRESS_MD" "$PACK_PATH/PROGRESS.md"
    exit $? ;;
  --selftest) exec bash "$HOOK_DIR/selftest/gate-tests.sh" ;;
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  "") ;;
  *) echo "evidence-gate: unknown option $1 (see --help)" >&2; exit 1 ;;
esac

cat > /dev/null 2>&1 || true               # the hook input is not needed here

[ -z "${GOALBUS_NESTED:-}" ] || exit 0      # sessions started by goal-bus.sh inherit these settings
[ -f "$GATE_FLAG" ] || exit 0               # not armed: a complete no-op
[ -f "$PROGRESS_MD" ] || exit 0

out="$(check_evidence "$PROGRESS_MD" "$PACK_PATH/PROGRESS.md")"
if [ -z "$out" ]; then
  rm -f "$GATE_STREAK_FILE"                     # passing resets the consecutive count
  exit 0
fi

n=$(( $(cat "$GATE_STREAK_FILE" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$GATE_STREAK_FILE"
if [ "$n" -gt "$GATE_BLOCK_LIMIT" ]; then
  rm -f "$GATE_STREAK_FILE"
  echo "The evidence gate has blocked $GATE_BLOCK_LIMIT times in a row and now lets this turn end to avoid a loop. The findings are still in PROGRESS.md; say so plainly in your report." >&2
  exit 0
fi

{
  echo "Evidence gate ($n/$GATE_BLOCK_LIMIT): PROGRESS.md has verdicts without the evidence the rules require, so you cannot stop yet."
  echo "$out"
  echo
  echo "Fix each one: quote the actual observation, or downgrade the verdict to BLOCKED and say what is missing."
  echo "Never invent a quotation to get past the gate. A quote must be something you observed in this session; if you cannot quote it, BLOCKED is the honest verdict."
} >&2
exit 2
