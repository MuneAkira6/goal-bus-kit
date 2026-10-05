#!/usr/bin/env bash
# lesson-coverage.sh — every lesson L1..L30 in docs/lessons.md must be guarded by at least one test
# case whose label carries its number, e.g. "[L15]".
set -uo pipefail
KIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
files=("$KIT"/hooks/selftest/*.sh "$KIT"/tests/*.sh)
missing=""; total=0
for i in $(seq 1 30); do
  n="$(cat "${files[@]}" | grep -c "\[L$i\]")"
  total=$((total + n))
  [ "$n" -gt 0 ] || missing="$missing L$i"
  printf 'L%-3s %3d case(s)\n' "$i" "$n"
done
if [ -f "$KIT/docs/lessons.md" ]; then
  for i in $(seq 1 30); do grep -qE "^## L$i " "$KIT/docs/lessons.md" || missing="$missing (L$i not in docs/lessons.md)"; done
fi
echo
if [ -n "$missing" ]; then echo "lesson coverage: missing$missing"; exit 1; fi
echo "lesson coverage: all 30 lessons are guarded ($total labelled cases)"
