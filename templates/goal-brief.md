# Goal brief — {{PACK_NAME}}

<!-- Template. Fill every {{slot}}. The sections "The evidence gate is mechanical", "There is a bus
     above you" and "Turn rhythm and progress protocol" are mechanism: keep them. The progress-line
     format is a machine interface; the hooks recognise the worker and its boundaries by it. -->

> This file is the worker's only entry point. Read all of it before you start.
> Human manual: [runbook.md](runbook.md). Ledger: [PROGRESS.md](PROGRESS.md). {{Scope / contract documents, if any}}
> Where it conflicts with the project's CLAUDE.md, the section "Deviations from the project rules" wins.

## Mission

{{One sentence: what this task builds, on top of what.}}

| Goal | Scope | In one line |
|---|---|---|
| G0 | — | {{environment check, baseline, contract freeze — usually no product code}} |
| G1 | {{…}} | {{the smallest change that proves the mechanism}} |
| … | … | … |
| Gn | — | {{joint acceptance, contract → AS-BUILT, change list}} |

Every AC is already listed in PROGRESS.md with its planned treatment (the "Plan" column). Do not add
or remove ACs; to change a plan, write the reason in PROGRESS.md first.

{{One sentence that sets the task's boundary, e.g. "consume the registry, do not build a second one".}}

## Required reading

| Resource | Why |
|---|---|
| {{the requirements source}} | the only authority for requirements; check every AC against it |
| {{upstream contracts or handoffs}} | as-built interfaces and conclusions already proven |
| {{test commands / skills}} | how verification is done here |

## Facts already verified ({{date}}, on {{machine the run will use}}) — use them, do not re-investigate

<!-- The investment that saves the worker whole turns: facts checked while the pack was written,
     each with its file:line or command and output. Check them on the machine the run will use:
     in the toy run this block described the author's laptop, the run went to a Linux host, and
     the operating system, the Node version and the install time it stated were all wrong there
     (the worker caught it and the bus upheld it). -->
- {{fact}}

## Deviations from the project rules ({{who authorised them}})

{{Rule that does not apply to this task, why, and what is allowed or required instead. Or "None".}}

## Definition of done for each goal

1. **Read first.** Read the current state before changing a file; line numbers here are pointers.
2. **It builds.** `{{build command}}` passes; paste the output.
3. **It runs.** {{how the change is applied}} and {{proof the running artifact changed, e.g. a hash}}.
4. **Every AC has a verdict** from the table below; nothing is left unexplained.
5. **PROGRESS.md first, report second.**
6. **The environment is restored.** Record and undo every change to shared data or settings.

### Verdicts

| Verdict | Meaning | Required |
|---|---|---|
| PASS | you observed what the AC describes | quote the observation (output, text, hash) |
| {{CITE_VERDICT_OR_DELETE}} | {{proven upstream}} | quote {{CITE_MARK_A}} and {{CITE_MARK_B}} |
| FAIL | the observation contradicts the AC | `expected "<X>" / actual "<Y>"`; if you cannot write that, it is not a FAIL |
| BLOCKED | you could not verify it | say what is missing |
| DEFERRED | it depends on an open decision | name the decision |

"Works as expected", "no issues" and "looks fine" count as unverified. When in doubt, BLOCKED — never
round an uncertainty up to PASS.

### The evidence gate is mechanical

`.claude/hooks/evidence-gate.sh` runs at the end of every turn while `{{TASK_DIR}}/.gate-on`
exists. It blocks the turn when a PASS has empty evidence, a weasel phrase or no quotation mark; when
a special verdict lacks one of its citations; when a FAIL is not "expected / actual"; when a BLOCKED
or DEFERRED gives no reason; or when a verdict word is unknown or forbidden.

It reads the file, not the conversation. So:
- **Never invent a quotation to pass it.** Quote only what you observed in this session. If you
  cannot, BLOCKED with the reason is the honest verdict and does not count against you.
- After {{GATE_BLOCK_LIMIT}} blocks in a row it lets the turn end to avoid a loop. Say so plainly in
  your report; the findings are still open.
- It checks only what must hold at every moment. Restoring the environment and rebuilding artifacts
  are still part of your definition of done.

### A/B and diffs

- To claim "the change causes X", show that without the change there is no X; the two arms must be
  different artifacts.
- Both arms must share the same environment and data. If they cannot, list every known difference
  (including the order of events and fixtures you changed) before attributing anything.
- {{task-specific diff rules, e.g. capture the record before and after each save}}

### Run batches one at a time

A setting such as "one worker" constrains one process, not how many processes you start. Start the
next long batch only after the previous one printed its summary line. Parallel runs produce failures
with normal-looking stack traces that cannot be told apart from real defects.

## Red lines — stop and report if you are about to cross one

1. Do not create, switch or modify branches.
2. Do not commit or push; the human commits between goals.
3. No writes to external systems.
4. No credentials in any document.
5. Do not fix unrelated existing problems; record them under "Incidental findings" in PROGRESS.md.
   A defect that **your own change** introduced is not unrelated: fix it in the same goal.
6. Nothing that installs or enables a tool outside this repository: no `corepack enable`, no
   `npm install -g`, no global installs of any kind. A CI workflow's setup steps run on CI only; here,
   verify only the project's own commands.
7. {{project-specific red lines}}

### There is a bus above you

While `{{TASK_DIR}}/.relay-on` exists, every turn you end meets the goal-bus Stop hook:
- **Inside a goal** it sends you back ("Continue Gn: N row(s)…"), so you do not need `/goal`. The
  hook reads PROGRESS.md, not the conversation: a table where every row has a verdict is the only
  way out.
- **When you print `PROGRESS: <goal> COMPLETE`** it checks the table and the evidence, then wakes the
  bus. The bus answers PASS (the next goal's instructions) or REJECT (what to fix).
- **The bus sees every earlier goal** and re-runs checks itself. Inventing a quotation will not
  survive it; BLOCKED will.

## Turn rhythm and progress protocol

- Each turn closes at least one AC end to end, including writing it to PROGRESS.md.
- End the turn with: `PROGRESS: <goal> ac_done=X/Y pass=a fail=c blocked=d deferred=e`
- When every row of the goal has a verdict, PROGRESS.md is written and the environment is restored:
  `PROGRESS: <goal> COMPLETE`
- When you are blocked: `PROGRESS: <goal> BLOCKED <reason>` — goal name first.
- The numbers must match PROGRESS.md. A false count voids the round.

**A turn must end on one of these lines. This is not formatting; it is what keeps the chain alive.**
The hooks run only when a turn ends, and they recognise you and your boundary by this line. End on
anything else — a status paragraph, "running it now" — and nobody is woken: your process ends and the
chain stops silently. It follows that:
- starting a long task in the background and ending the turn throws its result away;
- a long task is awaited with **one blocking call**, never by polling across turns, and the wait is
  anchored on an output (a summary line), not on "the log went quiet".

## After context compaction

1. Read PROGRESS.md and take the next empty verdict of the current goal.
2. If this brief is no longer in your context, read it again, completely.
3. {{Check that the frozen contract still holds.}}
4. {{A minimal check that the environment is alive.}}
