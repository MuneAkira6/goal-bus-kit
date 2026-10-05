#!/usr/bin/env bash
# quickstart-smoke.sh — follow the README quickstart in a throwaway repository, without calling the
# real CLI: install, check what was written, run both selftests there, and check the README keeps
# the quickstart at ten steps or fewer.
set -uo pipefail
KIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
P=0; F=0
ok() { P=$((P + 1)); printf 'ok    %s\n' "$1"; }
ng() { F=$((F + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
check() { if eval "$2"; then ok "$1"; else ng "$1" "$2"; fi; }

R="$(mktemp -d)"; trap 'rm -rf "$R"' EXIT
git -C "$R" init -q
# shellcheck disable=SC2034  # "out" is read inside the eval'd check below
out="$(bash "$KIT/install.sh" "$R" --task specs/demo --name "Demo & friends" --goals "G0 G1 G2" 2>&1)"; rc=$?
check "install exits 0"                                   "[ $rc -eq 0 ]"
check "hooks are in .claude/hooks"                        "[ -f '$R/.claude/hooks/goal-bus.sh' ] && [ -f '$R/.claude/hooks/lib/tables.awk' ]"
check "the task is written into bus.config.sh"            "grep -q 'GOALBUS_PACK_PATH:-specs/demo' '$R/.claude/hooks/bus.config.sh'"
check "a task name with & survives"                       "grep -q 'Demo & friends' '$R/.claude/hooks/bus.config.sh'"
check "the goal pack skeleton exists"                     "[ -f '$R/specs/demo/PROGRESS.md' ] && [ -f '$R/specs/demo/BUS-PROTOCOL.md' ] && [ -f '$R/specs/demo/goal-brief.md' ]"
check "template slots for the task dir are filled"        "grep -q 'specs/demo/.relay-on' '$R/specs/demo/goal-brief.md'"
check "run state is ignored in the task dir"              "grep -qx '.relay-state' '$R/specs/demo/.gitignore'"
check "settings.local.json was written"                   "[ -f '$R/.claude/settings.local.json' ]"
check "the explanatory keys were dropped from settings"    "! grep -q '__why' '$R/.claude/settings.local.json'"
check "both selftests passed inside the target"           "printf '%s' \"\$out\" | grep -c 'selftest: all passed' | grep -qx 2"
check "a second install refuses without --force"          "! bash '$KIT/install.sh' '$R' --task specs/demo --no-selftest >/dev/null 2>&1"
echo "# my config" >> "$R/.claude/hooks/bus.config.sh"
bash "$KIT/install.sh" "$R" --task specs/demo --force --no-selftest >/dev/null 2>&1
check "--force keeps an existing bus.config.sh"           "grep -q '# my config' '$R/.claude/hooks/bus.config.sh'"
( cd "$R" && bash .claude/hooks/goal-bus.sh --status > "$R/status.txt" 2>&1 )
check "status runs in the target and checks the settings" "grep -q '^settings   relay hook timeout 2520 s (ok)' '$R/status.txt'"

# the README quickstart: numbered steps inside the quickstart section, at most ten
steps="$(awk '/^## 動かし方/{f=1; next} /^## /{f=0} f && /^[0-9]+\. /{n++} END{print n+0}' "$KIT/README.md" 2>/dev/null)"
check "the README quickstart has 1–10 steps (found $steps)" "[ '${steps:-0}' -ge 1 ] && [ '${steps:-0}' -le 10 ]"

echo
echo "quickstart: $P passed, $F failed"
[ "$F" -eq 0 ]
