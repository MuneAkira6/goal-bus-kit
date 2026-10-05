---
marp: true
paginate: true
title: "The long-lived bus: running goals unattended"
---

# The long-lived bus
## Running goals unattended

Hand over a stack of tickets; it runs to the end, and afterwards you can audit every step.

Four stages, each with a prompt you can copy.

<!-- Speaker notes: the goal is that people can try this on their own long task tomorrow. Take home the why, not every detail. -->

---

## The whole picture

| Stage | What you type | What happens |
|---|---|---|
| 1. One goal | `/goal` with a done condition | at every turn end it checks the goal and pulls the agent back if unmet |
| 2. Several goals | instructions per goal | work proceeds in half-day slices |
| 3. The long-lived bus | "G1 is done." | the session that knows everything reviews and writes the next instructions |
| 4. Unattended | two latch files | hooks relay, and stop for a human on anything odd |

Each stage removes one more line of human involvement.

---

## Where it starts: one big prompt breaks in four ways

1. **Context is lost**: a long run forgets its early promises
2. **Standards drift**: "good enough" sinks halfway through
3. **Conclusions cannot be checked**: what did "verified" actually involve?
4. **Rework is expensive**: mistakes surface at the end

None of these raises an error. They all come back as "done".

---

## Stage 1: one goal

```text
/goal Fill the G1 table in specs/my-task/PROGRESS.md: every AC gets a verdict and quoted evidence.
Verdicts are PASS / FAIL / BLOCKED / DEFERRED. When unsure, BLOCKED.
```

At every turn end the goal is checked; if it is not met, the agent is pulled back in.

---

## The ceiling: the judge reads only the conversation

- The `/goal` evaluator is a small model that calls no tools
- It cannot open the judgment table or check that a quotation is real
- If the agent says "verified", that is all it has

No amount of prompt craft gets past this.

---

## The fix: move "done" into a file

- **A judgment table** (PROGRESS.md): a verdict and evidence per AC
- **A check script** (the evidence gate): reads the file at every turn end and refuses to let the turn end on an unsupported PASS
- When it refuses, it feeds the concrete problem back

```text
PASS with empty evidence / no quotation / only "looks fine"  -> try again
FAIL that is not "expected / actual"                       -> try again
```

---

## Evidence discipline

| Verdict | Required |
|---|---|
| PASS | a quotation of what was observed (output, page text, a hash) |
| FAIL | "expected X / actual Y" |
| BLOCKED | what is missing |
| DEFERRED | which decision it waits for |

**BLOCKED costs nothing. Inventing costs everything.** An honest BLOCKED beats a PASS rounded up from doubt.

---

## Stage 2: split into goals

- About half a day per goal
- G0 checks the environment and freezes the contract; no product code
- G1 is the smallest change that proves the mechanism
- The last goal: joint acceptance, the contract rewritten as AS-BUILT, the change list

```text
This goal is G1. Scope: …. Done when every row of G1 in PROGRESS.md has a verdict.
Never touch branches or commit; record unrelated problems instead of fixing them.
```

---

## The bottleneck moves to the human

At every goal boundary someone has to rewrite the next instructions.

- They must carry what the last goal found (environment facts, traps met)
- A fresh session cannot write them; it does not know the story
- So a human relays it from memory

---

## Stage 3: the long-lived bus

- **The session that wrote the goal pack** is woken again and again by its session id
- It reviews, gives a verdict (PASS / REJECT / ESCALATE / DONE) and writes the next instructions
- What a fresh reviewer cannot do: **use earlier goals' evidence to challenge this one**

```text
G1 is done. Review G1 in PROGRESS.md as BUS-PROTOCOL.md says,
and end with the BUS-VERDICT and BUS-NEXT blocks.
```

---

## What the bus writes

The runbook step, plus what earlier goals taught it:

- "The stack is already up; do not restart it."
- "Last time the two arms had different data. Align them and measure again."
- "This AC was proven in G1; cite it instead of re-running it."

In practice, about half of each instruction was not in the runbook at all.

---

## And still, a human relays the messages

The agents do the work, but a human still types "G1 is done."

At night, nobody does.

---

## Stage 4: unattended

Two Stop hooks. The two sessions only ever talk through files and scripts, so a broken chain can resume where it stopped.

- **The evidence gate**: bounces unsupported verdicts in seconds, without waking the bus
- **The relay**: inside a goal it counts empty cells and says "continue"; at a boundary it wakes the bus, parses the verdict and passes the next instructions on

---

## The decision flow

```text
worker turn ends
 ├─ inside a goal  -> count empty verdicts, say "continue"
 └─ G1 COMPLETE    -> table full? evidence gate passes?  -> no: bounce it back, for free
                    -> yes: wake the bus -> PASS: next instructions / REJECT: what to fix
                                         -> ESCALATE, DONE or anything odd: stop, wait for a human
```

Cheap checks first; the expensive review only at a clean boundary; always stop on an anomaly.

---

## Launch

```bash
bash .claude/hooks/goal-bus.sh --seed
touch specs/my-task/.gate-on specs/my-task/.relay-on
bash .claude/hooks/bin/start-worker.sh --file specs/my-task/g0-instructions.md
```

Delete the latch files and you are back to manual at any time.

---

## Numbers from real work (measured; the code is not public)

- 18 runs (August–September 2026)
- The first production run: 6 goals, 9 verdicts (3 REJECTs, each catching a real problem), 100 judgment rows with 0 FAIL, one human intervention
- A UI coverage effort in 12 streams: 446 judgment rows, 113 bus wake-ups
- The longest unattended stretch: 7 streams handed over automatically, 16 h 37 min

Bus-side cost is the CLI-reported `cost_usd` (an API-equivalent figure), not money spent.

---

## A regression the bus stopped

- Changing the post-login landing page broke navigation that was hard-coded elsewhere
- The worker reported "10 places in 4 files"; the bus recounted and found **11 places in 5 files**
- The worker wanted to leave it for the last goal; the bus refused: a regression this goal introduced is fixed in this goal

It was stopped before merge — the best single argument for the method.

---

## When to use it, when not to

**Use it** for work that spans several tickets and days, where every AC can be judged from an observation, in an environment where unattended permissions are acceptable, with a human who can take part asynchronously.

**Do not** for exploratory design, work that needs human rulings mid-goal, or one small fix.

Ask yourself: **"For every AC, can I name the observation that would prove it?"**

---

## The holes that are still open (no sugar-coating)

1. **A bus that approves without looking**: no mechanism prevents it. Keep the full review text and audit it by sampling
2. **ESCALATE reaches nobody**: it writes the log and stops
3. **A removed latch makes the hook go silent**: it cannot report that it stopped working

2 and 3 share a cause: a hook runs only when a turn ends, so it cannot notice that nothing is happening.

---

## Wrapping up

- The product is a judgment ledger you can audit later
- First step: `bash install.sh <your-repo> --task specs/my-task`
- The toolkit and 30 lessons: github.com/MuneAkira6/goal-bus-kit

<!-- Close: start with a small subject of about three goals; the toy-run record shows what one looks like. -->
