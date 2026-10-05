# Goal brief — csvq toy run

> This file is the worker's only entry point. Read all of it before you start.
> Contract: [SCOPE.md](SCOPE.md). Ledger: [PROGRESS.md](PROGRESS.md). Human manual: [runbook.md](runbook.md).

## Mission

Build `csvq`, a small CSV query CLI in TypeScript, inside `app/` — small enough to finish in three goals,
real enough that every acceptance criterion is judged from observed output.

| Goal | Scope | In one line |
|---|---|---|
| G0 | environment | check the toolchain, install, run the skeleton, measure the fixtures, freeze the contract |
| G1 | core | RFC 4180 reading, `--select`, `--where`, `--count`, `--sum` |
| G2 | finish | error handling and exit codes, `--format json`, performance, contract → AS-BUILT, README |

Every AC is already listed in PROGRESS.md. Do not add or remove ACs; to change a plan, write the reason
in PROGRESS.md first. Keep the tool small: nothing outside SCOPE.md.

## Required reading

| Resource | Why |
|---|---|
| [SCOPE.md](SCOPE.md) | the only authority for behaviour, exit codes and the CSV dialect |
| [PROGRESS.md](PROGRESS.md) | the rows you judge |

## Facts already verified (2026-09-29) — use them, do not re-investigate

- The machine runs Windows 11 with Git Bash. Node is v24.15.0 and pnpm 11.0.9 (through corepack).
- `pnpm install` for this `package.json` completes in about 25 seconds through the configured HTTPS proxy.
  The proxy comes from environment variables: **never unset them**.
- With vitest 5 no dependency needs a build script, so `allowBuilds: {}` with `strictDepBuilds: true` is
  correct; leave `pnpm-workspace.yaml` as it is.
- Node 24 runs `.ts` files directly (`node src/cli.ts`), so there is no build step; `pnpm typecheck`
  (TypeScript 7) is the compile check.
- Expected values from the fixtures: basic.csv has 5 records; the Osaka rows are Aiko (1200) and Chika
  (450), so their sum is 1650.

## Deviations from the project rules

None.

## Definition of done for each goal

1. **Read first.** Read the current state before changing a file.
2. **It type-checks.** `pnpm typecheck` passes; paste the output.
3. **It runs.** Judge behaviour by running `pnpm csvq …` (or `node src/cli.ts …`) and quoting the output.
4. **Every AC has a verdict** from the table below; nothing is left unexplained.
5. **PROGRESS.md first, report second.**
6. **Leave nothing behind.** Temporary files go to the OS temp directory; record anything you create
   outside `app/` in the change ledger.

### Verdicts

| Verdict | Meaning | Required |
|---|---|---|
| PASS | you observed what the AC describes | quote the observation (the command output) |
| FAIL | the observation contradicts the AC | `expected "<X>" / actual "<Y>"`; if you cannot write that, it is not a FAIL |
| BLOCKED | you could not verify it | say what is missing |
| DEFERRED | it depends on an open decision | name the decision |

"Works as expected", "no issues" and "looks fine" count as unverified. When in doubt, BLOCKED — never
round an uncertainty up to PASS.

### The evidence gate is mechanical

`.claude/hooks/evidence-gate.sh` runs at the end of every turn while `specs/csvq/.gate-armed` exists. It
blocks the turn when a PASS has empty evidence, a weasel phrase or no quotation mark; when a FAIL is not
"expected / actual"; when a BLOCKED or DEFERRED gives no reason; or when a verdict word is unknown.

It reads the file, not the conversation. So:
- **Never invent a quotation to pass it.** Quote only what you observed in this session. If you cannot,
  BLOCKED with the reason is the honest verdict and does not count against you.
- After 5 blocks in a row it lets the turn end to avoid a loop. Say so plainly in your report.

### Run commands one at a time

Run the performance measurement only after the tests have finished, and never start two test runs at once.

## Red lines — stop and report if you are about to cross one

1. Do not create, switch or modify branches.
2. Do not commit or push; the human commits between goals.
3. No writes to anything outside `examples/toy-run/app/` and `examples/toy-run/specs/csvq/`.
4. No credentials in any document. Do not unset or print the proxy environment variables.
5. Do not fix unrelated problems; record them under "Incidental findings". A defect **your own change**
   introduced is not unrelated: fix it in the same goal.
6. Do not edit the given fixtures or `pnpm-workspace.yaml`. No network access other than `pnpm install` in G0.

### There is a bus above you

While `specs/csvq/.bus-armed` exists, every turn you end meets the goal-bus Stop hook:
- **Inside a goal** it sends you back ("Continue Gn: N row(s)…"), so you do not need `/goal`. The hook
  reads PROGRESS.md, not the conversation: a table where every row has a verdict is the only way out.
- **When you print `PROGRESS: <goal> COMPLETE`** it checks the table and the evidence, then wakes the
  bus. The bus answers PASS (the next goal's instructions) or REJECT (what to fix).
- **The bus sees every earlier goal** and re-runs checks itself. An invented quotation will not survive
  it; BLOCKED will.

## Turn rhythm and progress protocol

- Each turn closes at least one row end to end, including writing it to PROGRESS.md.
- End the turn with: `PROGRESS: <goal> ac_done=X/Y pass=a fail=c blocked=d deferred=e`
- When every row of the goal has a verdict and PROGRESS.md is written: `PROGRESS: <goal> COMPLETE`
- When you are blocked: `PROGRESS: <goal> BLOCKED <reason>` — goal name first.
- The numbers must match PROGRESS.md.

**A turn must end on one of these lines. This is not formatting; it is what keeps the chain alive.**
The hooks run only when a turn ends, and they recognise you and your boundary by this line. End on
anything else and nobody is woken: your process ends and the chain stops silently. It follows that
starting a long task in the background and ending the turn throws its result away, and that a long task
is awaited with **one blocking call**, anchored on its output.

## After context compaction

1. Read PROGRESS.md and take the next empty verdict of the current goal.
2. If this brief is no longer in your context, read it again, completely, then SCOPE.md.
3. Check that SCOPE.md still says FROZEN (or AS-BUILT after G2).
4. Run `pnpm test` once to confirm the workspace is healthy.
