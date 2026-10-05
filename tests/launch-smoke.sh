#!/usr/bin/env bash
# launch-smoke.sh — run the toy-run launcher in a copy, with the fake CLI, and check it gets all the
# way to the worker. The launcher once died of SIGPIPE under pipefail one step before the worker.
set -uo pipefail
KIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
P=0; F=0
ok() { P=$((P + 1)); printf 'ok    %s\n' "$1"; }
ng() { F=$((F + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
check() { if eval "$2"; then ok "$1"; else ng "$1" "$2"; fi; }

L="$(mktemp -d)"; trap 'rm -rf "$L"' EXIT
T="$L/examples/toy-run"; C="$T/specs/csvq"
mkdir -p "$C" "$L/bin" "$L/fake" "$L/home/.claude"
git -C "$L" init -q
cp "$KIT/examples/toy-run/launch.sh" "$T/"
for f in SCOPE goal-brief PROGRESS BUS-PROTOCOL runbook BUS-MEMORY g0-instructions; do
  cp "$KIT/examples/toy-run/specs/csvq/$f.md" "$C/"
done
cp "$KIT/hooks/selftest/fake-claude" "$L/bin/claude"; chmod +x "$L/bin/claude"
# The launcher installs with both selftests; install here without them so this test stays fast.
bash "$KIT/install.sh" "$T" --task specs/csvq --name "csvq toy run" --goals "G0 G1 G2" --no-selftest > "$L/install.out" 2>&1
check "the kit installs into the copy"                   "[ -f '$T/.claude/hooks/goal-bus.sh' ]"
(
  unset CLAUDE_PROJECT_DIR GOALBUS_ENV_FILE   # the operator's environment stays out of the copy
  export HOME="$L/home" CLAUDE_CONFIG_DIR="$L/home/.claude" PATH="$L/bin:$PATH" FAKE_DIR="$L/fake" FAKE_TASK_DIR="$C"
  bash "$T/launch.sh" > "$L/launch.out" 2>&1
); rc=$?
check "the launcher exits 0"                             "[ $rc -eq 0 ]"
check "it seeds the bus"                                 "[ -s '$C/.bus-sid' ]"
check "it arms both latches"                             "[ -f '$C/.relay-on' ] && [ -f '$C/.gate-on' ]"
check "it prints the whole status, not just its head"    "grep -q '^G2 rows without a verdict:' '$L/launch.out'"
check "it gets to the worker"                            "grep -q '^== 4/4' '$L/launch.out' && [ -s '$C/.worker-sid' ]"
check "the bus is seeded as a child session"             "grep -q '|child=1|mode=new|' '$L/fake/calls.log'"
check "the worker is not a child, and runs unattended"   "grep -q '|child=|mode=new|' '$L/fake/calls.log' && grep -q 'bypassPermissions' '$L/fake/calls.log'"
check "exactly two sessions are started"                 "[ \"\$(grep -c '|mode=new|' '$L/fake/calls.log')\" = 2 ]"
[ "$F" -eq 0 ] || { echo "--- launcher output"; cat "$L/launch.out"; }

echo
echo "launch: $P passed, $F failed"
[ "$F" -eq 0 ]
