#!/usr/bin/env bash
# install.sh — install goal-bus-kit into a repository.
#
#   bash install.sh <target-repo> --task <dir> [--name "<task name>"] [--goals "G0 G1 G2"] [--force] [--no-selftest]
#
#   1. copies hooks/ to <target-repo>/.claude/hooks/ and writes the task into bus.config.sh
#   2. creates <task-dir>/ from the templates (existing files are never overwritten)
#   3. writes .claude/settings.local.json if there is none; otherwise prints what to merge
#   4. runs both selftests inside the target repository
set -euo pipefail
# bash 5.2 expands "&" in the replacement of ${var//pattern/replacement}; task names may contain one.
shopt -u patsub_replacement 2>/dev/null || true

KIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
die() { echo "install: $*" >&2; exit 1; }

TARGET="" TASK="" NAME="" GOAL_LIST="G0 G1 G2" FORCE="" SELFTEST=1
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --goals) GOAL_LIST="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --no-selftest) SELFTEST=""; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) TARGET="$1"; shift ;;
  esac
done
[ -n "$TARGET" ] && [ -d "$TARGET" ] || die "give an existing target repository as the first argument"
[ -n "$TASK" ] || die "--task <dir> is required (a path relative to the repository root, e.g. specs/my-task)"
case "$TASK" in /*|*..*) die "--task must be a relative path inside the repository" ;; esac
NAME="${NAME:-$TASK}"
for v in "$TASK" "$NAME" "$GOAL_LIST"; do
  case "$v" in *'"'*|*'$'*|*'`'*|*'\'*) die "quotes, \$, backticks and backslashes are not allowed in --task, --name or --goals" ;; esac
done
n=0
for g in $GOAL_LIST; do
  [[ "$g" =~ ^G[0-9]+$ ]] || die "goal names must look like G0, G1, …; got '$g'"
  n=$((n + 1))
done
[ "$n" -ge 2 ] || die "--goals needs at least two goals"
command -v jq >/dev/null || die "jq is required (https://jqlang.org)"

TARGET="$(cd "$TARGET" && pwd)"
H="$TARGET/.claude/hooks"
if [ -f "$H/bus.config.sh" ] && [ -z "$FORCE" ]; then
  die "already installed in $H (use --force to update the hooks; your bus.config.sh is kept)"
fi

# 1. hooks
mkdir -p "$H"
keep=""
[ -f "$H/bus.config.sh" ] && keep="$(cat "$H/bus.config.sh")"
cp -R "$KIT/hooks/." "$H/"
if [ -n "$keep" ]; then
  printf '%s\n' "$keep" > "$H/bus.config.sh"
  echo "hooks updated; kept your existing bus.config.sh"
else
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      'PACK_PATH='*) printf 'PACK_PATH="${GOALBUS_PACK_PATH:-%s}"\n' "$TASK" ;;
      'PACK_NAME='*)    printf 'PACK_NAME="${GOALBUS_PACK_NAME:-%s}"\n' "$NAME" ;;
      'GOAL_LIST='*)        printf 'GOAL_LIST="${GOALBUS_GOAL_LIST:-%s}"\n' "$GOAL_LIST" ;;
      *)                printf '%s\n' "$line" ;;
    esac
  done < "$KIT/hooks/bus.config.sh" > "$H/bus.config.sh"
  echo "hooks installed in .claude/hooks (task $TASK, goals: $GOAL_LIST)"
fi
chmod +x "$H"/*.sh "$H"/bin/*.sh "$H"/selftest/*.sh "$H"/selftest/fake-claude 2>/dev/null || true

# 2. the goal pack skeleton
T="$TARGET/$TASK"
mkdir -p "$T"
for f in BUS-PROTOCOL.md goal-brief.md runbook.md PROGRESS.md BUS-MEMORY.md; do
  if [ -f "$T/$f" ]; then echo "kept existing $TASK/$f"; continue; fi
  c="$(cat "$KIT/templates/$f")"
  c="${c//\{\{TASK_DIR\}\}/$TASK}"
  c="${c//\{\{PACK_NAME\}\}/$NAME}"
  printf '%s\n' "$c" > "$T/$f"
done
if ! grep -qs '^\.relay-state$' "$T/.gitignore"; then
  printf '%s\n' .gate-on .gate-streak .relay-on .bus-sid .relay-state .relay-lock .next-step .relay-paused \
    .worker-sid .worker-output .watch-state >> "$T/.gitignore"
fi
echo "goal pack skeleton in $TASK/ (fill every {{slot}})"

# 3. settings
S="$TARGET/.claude/settings.local.json"
if [ -f "$S" ]; then
  echo
  echo "$S already exists; merge these two blocks into it by hand (see templates/settings.hooks.json):"
  jq '{permissions, hooks}' "$KIT/templates/settings.hooks.json"
else
  jq 'del(.__how_to_use, .__why)' "$KIT/templates/settings.hooks.json" > "$S"
  echo "wrote .claude/settings.local.json (bypassPermissions + deny, both Stop hooks, timeout 2520)"
fi

# 4. selftests, in the target, with the configuration just written
if [ -n "$SELFTEST" ]; then
  echo
  echo "running both selftests in the target (this takes a while on Windows)…"
  ( cd "$TARGET" && bash .claude/hooks/goal-bus.sh --selftest | tail -n 2 && bash .claude/hooks/evidence-gate.sh --selftest | tail -n 2 ) \
    || die "a selftest failed in the target; do not arm the relay until it is green"
fi

cat <<EOF

Next:
  1. Fill the goal pack in $TASK/ and write the first goal's instructions (e.g. $TASK/g0-instructions.md).
  2. Create your branch.
  3. bash .claude/hooks/goal-bus.sh --seed
  4. touch $TASK/.gate-on $TASK/.relay-on
  5. bash .claude/hooks/bin/start-worker.sh --file $TASK/g0-instructions.md
  6. bash .claude/hooks/bin/watch.sh
EOF
