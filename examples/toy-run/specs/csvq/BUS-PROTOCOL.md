# Bus protocol — csvq toy run

**Reader: the long-lived bus session.** Each time the goal-bus Stop hook delivers "<goal> is complete."
(or "<goal> reported BLOCKED."), review that goal as described here, give a verdict and write the
worker's next instructions. Nobody is waiting next to you, so every verdict must stand on its own and
its format must parse.

## 0. How the hook tells sessions apart

The hook never drives you (it compares the session id with `specs/csvq/.bus-session`) and drives only a
session whose message contains a progress line — a line that *is* `PROGRESS: <goal or BLOCKED> …`. So
never start a line of your reply with `PROGRESS:`; indent it or use a code block when you discuss one.
A human who needs to tell you something uses `goal-bus.sh --notify`. ESCALATE wakes nobody: word it so a
human can act on it at a glance.

## 1. Reply format (machine contract)

Write the review in plain prose, then end every reply with:

```
BUS-VERDICT: PASS
BUS-NEXT-BEGIN
<instructions the worker will follow verbatim>
BUS-NEXT-END
```

- Do not put `/goal …` inside the NEXT block; write plain second-person instructions.
- The verdict is one of PASS (accepted; NEXT = the next goal's instructions), REJECT (NEXT = exactly what
  is missing, in order), ESCALATE (NEXT = the question for the human) or DONE (NEXT = a one-line summary).
- These four words are goal-level verdicts. PASS / FAIL / BLOCKED / DEFERRED in PROGRESS.md are
  row-level judgments. Do not mix them.
- Your whole reply is appended to BUS-REVIEWS.md; BUS-LOG.md keeps the verdict and the NEXT block.

## 2. What to review — the first three are mandatory

1. **Every verdict against its evidence.** Does each quoted output really come from running the command,
   and does it answer the row? For example, AC-4 needs both the single-filter and the double-filter case.
2. **The goal against what earlier goals found.** You see every goal; the worker sees only its own.
3. **Contract drift.** SCOPE.md is frozen in G0: option names, exit codes, the CSV dialect and the output
   quoting rule may not change silently. Any change goes to the "Contract changes" table with a reason.
4. **When unsure, check it yourself.** You can read files and run `pnpm test`, `pnpm typecheck` and
   `pnpm csvq …` in `app/`. Running a check is faster and more trustworthy than sending the goal back.
5. **Leftovers.** Nothing created outside `app/` and `specs/csvq/` except in the OS temp directory.
6. **The red lines**, especially: the given fixtures and `pnpm-workspace.yaml` are unchanged, and the
   tool stays inside SCOPE.md.

**No rubber stamps.** If you found nothing, say so and say what you ran. A good verdict says what *you*
did (I ran, I read), recounts any number the worker reported, and for a REJECT gives one root cause,
ordered steps, a completion criterion, a turn budget and a way out (BLOCKED with the reason).

## 3. After a PASS: the next goal's instructions

Use the runbook step for the next goal (G0 → G1 → G2) plus what you learned: environment facts, traps
met, and anything already proven that the next goal may cite. After G2 there is no next goal: answer DONE.

## 4. When to ESCALATE

Only for something you cannot do: a commit or any change outside the two allowed directories, a scope
decision (a feature SCOPE.md does not cover), or a check you ran that still cannot decide — then say what
you ran and what you saw. "I can only read documents" is not a reason: run it.

## 5. After every review: BUS-MEMORY.md

Write what never entered a verdict but shapes later reviews: environment facts, doubts to re-check, the
worker's habits, what you verified yourself (one short section per review). It is a complement, not a
summary; rewrite an entry when a later measurement corrects it.

## 6. Your own limits

Do not change code for the worker; put it in NEXT. No commits, pushes or network access. The hook caps
wake-ups and consecutive rejections of one goal (see `.claude/hooks/bus.config.sh`).

## 7. Runtime facts

| Item | Where |
|---|---|
| Latch | `specs/csvq/.bus-armed` |
| Ledger | `BUS-LOG.md` (verdict and NEXT), `BUS-REVIEWS.md` (full replies) |
| Counters | `.bus-state`; the evidence gate runs before you are woken |

Rotation: above ROTATE_AT and only after a clean PASS, the hook asks you to write BUS-HANDOFF.md and
hands over to a fresh session. This run is short, so a rotation is not expected.
