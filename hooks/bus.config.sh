# bus.config.sh — the only file you edit for a new task. Both hooks and the helper scripts source it.
# Every value can be overridden with the GOALBUS_* environment variable named next to it.
# After editing, run both selftests from the repository root. Their fixtures are built from these
# values, so green means "this configuration is coherent on this machine":
#   bash .claude/hooks/evidence-gate.sh --selftest
#   bash .claude/hooks/goal-bus.sh --selftest

# --- the goal pack -------------------------------------------------------------------------------
# Directory of the goal pack, relative to the repository root.
PACK_PATH="${GOALBUS_PACK_PATH:-specs/CHANGE-ME}"
# Human-readable task name (used when a bus is seeded or rotated).
PACK_NAME="${GOALBUS_PACK_NAME:-CHANGE-ME}"
# Goal sequence, space-separated, at least two. Names are G<number>; a one-letter suffix (G1b) is
# reserved for follow-up goals the bus mints during a run, so do not list those here.
GOAL_LIST="${GOALBUS_GOAL_LIST:-G0 G1 G2}"

# --- judgment tables -----------------------------------------------------------------------------
# A table is machine-checked only when its header has a cell equal to VERDICT_HEADER and a cell that
# contains EVIDENCE_HEADER. Environment and ledger tables use other headers on purpose.
VERDICT_HEADER="${GOALBUS_VERDICT_HEADER:-Verdict}"
EVIDENCE_HEADER="${GOALBUS_EVIDENCE_HEADER:-Evidence}"
# Phrases that make a PASS count as unverified ("|"-separated, case-insensitive substrings).
WEASEL_WORDS="${GOALBUS_WEASEL_WORDS:-works as expected|as expected|looks fine|looks good|seems fine|seems ok|no issues|no problem|should be fine|displays correctly|appears correct}"
# A FAIL must read: <expected-word> "<X>" / <actual-word> "<Y>".
FAIL_EXPECTED_WORD="${GOALBUS_FAIL_EXPECTED_WORD:-expected}"
FAIL_ACTUAL_WORD="${GOALBUS_FAIL_ACTUAL_WORD:-actual}"
# Optional citation-type verdict for values already proven upstream, e.g. PASS(REF). Empty disables it.
# Its evidence must contain both markers, and CITE_MARK_B must point outside this task's directory
# (a marker the task's own PROGRESS.md can satisfy checks nothing).
CITE_VERDICT="${GOALBUS_CITE_VERDICT:-}"
CITE_MARK_A="${GOALBUS_CITE_MARK_A:-}"
CITE_MARK_B="${GOALBUS_CITE_MARK_B:-}"
# Verdict words that must not appear at all in this task ("|"-separated). Emptying CITE_VERDICT does
# not forbid PASS(REF); it only stops asking for two citations. This does forbid it.
BANNED_VERDICTS="${GOALBUS_BANNED_VERDICTS:-}"
# Shown when a DEFERRED row has no reason.
WAITS_FOR_HINT="${GOALBUS_WAITS_FOR_HINT:-the open decision it waits for}"

# --- caps ----------------------------------------------------------------------------------------
# Calibrate every count-based cap on day one: measure what one complete run needs and set the cap
# above that. A cap below the real need never fires while things go well, so it looks green forever.
WAKE_LIMIT="${GOALBUS_WAKE_LIMIT:-30}"          # bus wake-ups allowed in total (cost brake)
REJECT_LIMIT="${GOALBUS_REJECT_LIMIT:-3}"           # consecutive REJECTs of one goal before a human is asked
GATE_BLOCK_LIMIT="${GOALBUS_GATE_BLOCK_LIMIT:-5}"   # consecutive evidence-gate blocks before it lets go
TURN_LIMIT="${GOALBUS_TURN_LIMIT:-40}"     # worker turns inside one goal (runaway brake)
# Goals after whose PASS the relay stops on purpose (space-separated), e.g. to split a long task over
# several working days. The next instructions are kept; print them with: goal-bus.sh --next
PAUSE_AFTER="${GOALBUS_PAUSE_AFTER:-}"

# --- time budgets (seconds) ----------------------------------------------------------------------
REVIEW_TIMEOUT="${GOALBUS_REVIEW_TIMEOUT:-1740}"            # one review; the bus may re-run checks itself
HANDOFF_TIMEOUT="${GOALBUS_HANDOFF_TIMEOUT:-300}"   # the handoff and the seeding, each
# The goal-bus hook "timeout" in settings must exceed REVIEW_TIMEOUT + 2*HANDOFF_TIMEOUT + 60
# (review + handoff + seeding in the worst case; 2400 with the defaults, so configure 2520).
# If Claude Code kills the hook first, the paid review is lost and nothing reaches BUS-LOG.md.

# --- models and context rotation -----------------------------------------------------------------
BUS_MODEL="${GOALBUS_BUS_MODEL:-opus[1m]}"
WORKER_MODEL="${GOALBUS_WORKER_MODEL:-opus[1m]}"
# The defaults assume a 1M-token context window (rotate at about 65%). For a 200k window set BOTH:
# GOALBUS_ROTATE_TOKENS=130000 and GOALBUS_WARN_TOKENS=80000; lowering only the first silences the warning.
ROTATE_TOKENS="${GOALBUS_ROTATE_TOKENS:-650000}"
WARN_TOKENS="${GOALBUS_WARN_TOKENS:-400000}"

# GOALBUS_ENV_FILE (environment only, no default): a file every bus call sources just before `claude`.
# Use it when the hook's environment lacks something the CLI needs. Seen on a Linux host whose CLI
# authenticates with CLAUDE_CODE_OAUTH_TOKEN: the token did not reach the Stop hooks, so the bus
# answered "Not logged in" (CLAUDE_CONFIG_DIR did arrive). Keep only `. <file>` and `export` lines in
# it, never a secret value; a proxy setting that lives in a login script belongs there too.

# Tools the bus may use on a wake-up. Headless runs deny every tool that is not listed.
REVIEW_TOOLS="${GOALBUS_REVIEW_TOOLS:-Read,Grep,Glob,Write,Edit,Bash}"
