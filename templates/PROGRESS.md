# {{PACK_NAME}} — progress ledger

<!-- Structure the hooks rely on:
     1. Each goal is an h2 section "## Gk — name". Sub-sections inside a goal are h3 (###).
        Everything else (appendix, findings) must also start with an h2, or its rows count toward the last goal.
     2. A machine-checked table has a "Verdict" column and a column whose header contains "Evidence".
        The environment table below uses "Proof" and the change ledger has no Verdict column, so the gate
        leaves them alone.
     3. An empty verdict means "not done yet", which is allowed. Once a verdict is filled in, the
        evidence rules apply to its row. -->

**Status: {{in progress / done}} ({{date}}).** When the run is done, read "Handover" first.

Verdicts: PASS / {{CITE_VERDICT_OR_DELETE}} / FAIL / BLOCKED / DEFERRED (defined in goal-brief.md).
The "Plan" column is the treatment fixed before the run; to change it, write the reason here first.
A measured AC names how it is invoked (for example `node src/cli.ts` rather than a package-manager
script), or the launcher's own start-up time decides the verdict: the toy run's bus had to rule on it.
Two accepted shapes: a split verdict (for example "**PASS** (UI half) / API half **DEFERRED**") and an
annotated PASS ("**PASS** (hash unchanged, stated as is)"). An empty verdict left on purpose must be
explained somewhere in this file.

## Environment (filled in G0; every row with the command and its output)

| Item | Value | Proof |
| --- | --- | --- |
| Branch | {{value}} | {{command → output}} |
| {{service health}} | {{value}} | {{command → output}} |
| {{baseline artifact fingerprint}} | {{value}} | {{command → output}} |

## Environment change ledger (before → change → restored)

<!-- Capture the value before changing it, word for word; after restoring, read it back and compare. -->

| # | Goal | Object | Before | Change | Restored |
| --- | --- | --- | --- | --- | --- |
| 1 | G0 | {{object}} | {{value before}} | {{change and its receipt}} | {{read back, identical}} |

## Contract changes (frozen in G0; any later rename or reshape goes here)

| Date | Entry | Content |
| --- | --- | --- |
| {{date}} | {{frozen / changed / added}} | {{what, why, which documents were updated}} |

---

## G0 — {{environment check and contract freeze}}

| Condition | Verdict | Evidence |
| --- | --- | --- |
| {{condition 1}} | | |
| {{condition 2}} | | |

## G1 — {{name}}

### {{feature or ticket}}

| AC | Item | Plan | Verdict | Evidence |
| --- | --- | --- | --- | --- |
| AC-1 | {{short}} | {{measure / implement / DEFERRED}} | | |
| AC-2 | {{short}} | {{…}} | | |

### G1 checks

| Check | Verdict | Evidence |
| --- | --- | --- |
| Built, applied, and the running artifact changed (fingerprint) | | |
| One mechanism only (a search shows no second one) | | |
| The change set matches the claim (`git diff --stat`) | | |

<!-- If a goal fixes a defect it introduced itself, add "### Introduced and fixed in Gk": the symptom
     as measured, the cause, the fix, the evidence after the fix, and the explanations ruled out. -->

## G{{n}} — closing (joint acceptance, contract → AS-BUILT, change list)

| Condition | Verdict | Evidence |
| --- | --- | --- |
| Joint acceptance: both arms from the same artifact at the same time | | |
| The contract rewritten as AS-BUILT, each difference marked | | |
| Change list, requirement → change map, proposed commits | | |
| Every row of the environment ledger restored | | |
| No unexplained empty verdict anywhere | | |

---

## Handover (filled at the end; each item = fact, impact, the decision needed)

<!-- Only what cannot be solved without a decision the agents may not make. Keep the three parts. -->

### 1. {{title}}

**Fact:** {{quoted observation or code reference}}
**Impact:** {{on what is delivered}}
**Decision needed:** {{one clear question}}

### Rulings (filled after the handover)

| # | Ruling | Carried out |
| --- | --- | --- |

## Appendix — {{conditional items}}

<!-- Must be an h2. Explain here why a table is left empty on purpose. -->

## Incidental findings (recorded, not fixed)

| # | Finding | Where | Note |
| --- | --- | --- | --- |
