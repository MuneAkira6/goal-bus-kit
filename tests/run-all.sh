#!/usr/bin/env bash
# run-all.sh — everything CI runs. Set GOALBUS_AWK=mawk (or gawk) to force one awk implementation.
set -uo pipefail
KIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$KIT" || exit 1
fail=0
run() { echo; echo "=== $*"; "$@" || fail=1; }
run bash hooks/goal-bus.sh --selftest
run bash hooks/evidence-gate.sh --selftest
run bash tests/templates.sh
run bash tests/quickstart-smoke.sh
run bash tests/launch-smoke.sh
run bash tests/lesson-coverage.sh
echo
if [ "$fail" -eq 0 ]; then echo "run-all: every suite passed (awk: ${GOALBUS_AWK:-awk})"; else echo "run-all: FAILED (awk: ${GOALBUS_AWK:-awk})"; fi
exit "$fail"
