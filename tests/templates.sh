#!/usr/bin/env bash
# templates.sh — repository-level checks that the templates and documents still say what the
# mechanism relies on, and that their machine-readable examples parse with the real parser.
set -uo pipefail
KIT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="$KIT/hooks"
. "$HOOK_DIR/bus.config.sh"
. "$HOOK_DIR/lib/common.sh"
P=0; F=0
ok() { P=$((P + 1)); printf 'ok    %s\n' "$1"; }
ng() { F=$((F + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
has() { if grep -qF -- "$2" "$3"; then ok "$1"; else ng "$1" "missing [$2] in ${3#$KIT/}"; fi; }
T="$KIT/templates"

# --- machine contracts in the templates must parse with the hook's own parser --------------------
block="$(sed -n '/^```$/,/^```$/p' "$T/BUS-PROTOCOL.md" | sed '1d;$d' | head -n 4)"
[ "$(printf '%s\n' "$block" | read_verdict)" = PASS ] && ok "[L26] the protocol's example block parses as PASS" || ng "[L26] the protocol's example block parses as PASS" "$block"
[ -n "$(printf '%s\n' "$block" | read_next_block)" ] && ok "[L26] ... and its NEXT block is found" || ng "[L26] ... and its NEXT block is found" "$block"
line="$(grep -o 'PROGRESS: <goal> COMPLETE' "$T/goal-brief.md" | head -n 1 | sed 's/<goal>/G1/')"
[ "$(closing_kind "$line")" = COMPLETE ] && ok "[L17] the brief's boundary line is a boundary" || ng "[L17] the brief's boundary line is a boundary" "$line"
line="$(grep -o 'PROGRESS: <goal> BLOCKED <reason>' "$T/goal-brief.md" | head -n 1 | sed 's/<goal>/G1/')"
[ "$(closing_goal "$line")" = G1 ] && ok "[L28] the brief's BLOCKED line books its goal" || ng "[L28] the brief's BLOCKED line books its goal" "$line"
line="$(grep -o 'PROGRESS: <goal> ac_done=X/Y[^`]*' "$T/goal-brief.md" | head -n 1 | sed 's/<goal>/G1/')"
has_signature "$line" && [ -z "$(closing_kind "$line")" ] && ok "[L15] the brief's progress line is a signature, not a boundary" || ng "[L15] the brief's progress line is a signature, not a boundary" "$line"
tmp="$(mktemp -d)"
sed 's/{{[^}]*}}/x/g; s/^## G{{n}}/## G2/' "$T/PROGRESS.md" | sed 's/^## Gx /## G2 /' > "$tmp/P.md"
[ "$(open_rows G1 "$tmp/P.md")" -gt 0 ] && ok "[L7] the PROGRESS template's goal tables are counted" || ng "[L7] the PROGRESS template's goal tables are counted" "$(open_rows G1 "$tmp/P.md")"
check_evidence "$tmp/P.md" >/dev/null && ok "[gate] an unfilled PROGRESS template has no violations" || ng "[gate] an unfilled PROGRESS template has no violations" "$(check_evidence "$tmp/P.md")"
rm -rf "$tmp"

# --- settings ---------------------------------------------------------------------------------------
t="$(settings_timeout_ok "$T/settings.hooks.json")" && ok "[L1] the settings template's hook timeout ($t s) covers a review plus a rotation" \
  || ng "[L1] the settings template's hook timeout covers a review plus a rotation" "timeout $t"
[ "$(jq -r .permissions.defaultMode "$T/settings.hooks.json" | tr -d '\r')" = bypassPermissions ] && ok "[L10] unattended runs use bypassPermissions" || ng "[L10] unattended runs use bypassPermissions" ""
for d in 'Bash(git commit:*)' 'Bash(git push:*)' 'Bash(gh pr create:*)'; do
  jq -e --arg d "$d" '.permissions.deny | index($d)' "$T/settings.hooks.json" >/dev/null && ok "[L10] deny keeps '$d' with the human" || ng "[L10] deny keeps '$d' with the human" ""
done

# --- the rules the templates must keep saying ----------------------------------------------------------
has "[L11] BUS-MEMORY is a complement, not a summary"             "complement, not a summary" "$T/BUS-MEMORY.md"
has "[L11] ... and stale entries must be rewritten"               "come back and rewrite it" "$T/BUS-MEMORY.md"
has "[L14] the protocol forbids rubber stamps"                    "No rubber stamps" "$T/BUS-PROTOCOL.md"
has "[L14] the runbook has the rubber-stamp audit"                "Rubber-stamp audit" "$T/runbook.md"
has "[bonus] the protocol keeps the two vocabularies apart"       "Two vocabularies" "$T/BUS-PROTOCOL.md"
has "[L8] NEXT must be plain instructions, not a slash command"   'Do not put `/goal …` inside the NEXT block' "$T/BUS-PROTOCOL.md"
has "[L9] a special verdict needs two citations"                  "quote {{CITE_MARK_A}} and {{CITE_MARK_B}}" "$T/goal-brief.md"
has "[L20] a turn must end on a boundary line"                    "A turn must end on one of these lines" "$T/goal-brief.md"
has "[L20] ... and a background task is not awaited across turns" "one blocking call" "$T/goal-brief.md"
has "[L21] long batches run one at a time"                        "Run batches one at a time" "$T/goal-brief.md"
has "[L24] the runbook checks every tree, machine and person before arming" "no other armed pack in any working tree or on any" "$T/runbook.md"
has "[bonus] a defect your own change introduced is fixed in the same goal" "fix it in the same goal" "$T/goal-brief.md"

# --- no notification channel is wired in (L22) --------------------------------------------------------
if grep -rniE 'terminalSequence|toast|notify-send|osascript|msg\.exe|BurntToast|PushNotification' "$KIT/hooks" >/dev/null; then
  ng "[L22] no notification channel is wired into the hooks" "$(grep -rniE 'terminalSequence|toast|notify-send|osascript|msg\.exe|BurntToast|PushNotification' "$KIT/hooks" | head -n 3)"
else ok "[L22] no notification channel is wired into the hooks"; fi
if [ -f "$KIT/docs/method.md" ]; then
  has "[L22] the method states the open notification gap"          "通知の穴" "$KIT/docs/method.md"
  has "[L23] the method states that a headless turn end is the process end" "ターンの終わりがプロセスの終わり" "$KIT/docs/method.md"
  has "[L24] the method asks for a runtime check before every shared write" "書き込むたびに" "$KIT/docs/method.md"
else ng "[L22] docs/method.md exists" "missing"; fi

echo
echo "templates: $P passed, $F failed"
[ "$F" -eq 0 ]
