#!/usr/bin/env bash
# launch.sh — start the csvq toy run with goal-bus-kit (the operator's single command).
# It does the kit's quickstart steps for you: installs the hooks here the first time, seeds the bus,
# arms both latches and starts the worker in the foreground. From then on the relay drives the run
# without a human until DONE, ESCALATE, a cap or an anomaly.
# Watch it from another terminal: cd examples/toy-run && bash .claude/hooks/bin/watch.sh 60
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"

echo "== 1/4 install the hooks (first time only; the generic 'Next:' steps it prints are done below)"
if [ ! -f .claude/hooks/goal-bus.sh ]; then
  bash "$KIT/install.sh" "$HERE" --task specs/csvq --name "csvq toy run" --goals "G0 G1 G2"
fi
echo "== 2/4 seed the bus (first time only)"
if [ ! -f specs/csvq/.bus-sid ]; then
  bash .claude/hooks/goal-bus.sh --seed
fi
echo "== 3/4 arm both latches"
touch specs/csvq/.gate-on specs/csvq/.relay-on
# The whole status, never "| head": under pipefail a reader that quits early kills the writer with
# SIGPIPE, and set -e then ends this script before the worker starts.
bash .claude/hooks/goal-bus.sh --status
echo
echo "== 4/4 start the worker; the relay drives it until DONE, ESCALATE, a cap or an anomaly"
echo "   (this terminal stays busy; watch from another one: cd $HERE && bash .claude/hooks/bin/watch.sh 60)"
bash .claude/hooks/bin/start-worker.sh --file specs/csvq/g0-instructions.md
