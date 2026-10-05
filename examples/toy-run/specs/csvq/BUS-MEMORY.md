# Bus memory — csvq toy run

**This is a complement, not a summary.** Anything in PROGRESS.md, BUS-LOG.md or the goal brief does not
belong here. When a later measurement corrects an entry, come back and rewrite it. Marks: 🆕 new ·
✅ verified · 🔴 warning · ~~struck~~ no longer true.

## Environment facts across goals

- ~~Windows 11 with Git Bash; Node v24.15.0; pnpm 11.0.9 through corepack.~~ Written from the pack
  author's machine, not this one. Corrected after G0.
- ✅ This run is on **Linux 5.4.0-216-generic**, Node **v24.19.0**, pnpm **11.22.0** on PATH. I ran
  `node --version`, `pnpm --version` and `uname -sr` myself during the G0 review.
- ✅ The install runs under **pnpm 11.0.9**, not the 11.22.0 on PATH: corepack honours
  `"packageManager": "pnpm@11.0.9"` in `app/package.json`. Any version-sensitive note must name 11.0.9.
- ✅ An HTTPS proxy is configured (`http_proxy`, `https_proxy`, `no_proxy` and the uppercase forms are
  all set — I checked the names, not the values). The worker must not unset or print them.
- ~~`pnpm install` took about 25 seconds.~~ On this box with a warm store it took **1.6 s wall**
  (pnpm's own figure 787 ms). No dependency needs a build script, so `strictDepBuilds: true` with
  `allowBuilds: {}` never fired.
- ✅ **Node runs `.ts` files directly** here (native type stripping). I ran a throwaway typed script
  through `node` and it printed the right answer at exit 0. This matters: `app/package.json` wires
  `"csvq": "node src/cli.ts"` and `"bin"` to a `.ts` file, so there is no build step in this project
  and nobody should add one. `tsconfig.json` sets `noEmit`, `verbatimModuleSyntax` and
  `allowImportingTsExtensions` — so intra-project imports must be written **with** the `.ts` suffix,
  and type-only imports must say `import type`.

## Doubts to re-check

- ~~`pnpm lint` reports "Checked 2 files" with only one real source file.~~ Resolved at G1: the count
  grew to 4 as three source files appeared, so Biome is counting what it should. No longer a worry.
- 🆕 `src/cli.ts` reads a bare argument as the file name with no check, so **the last bare argument
  silently wins** and a misspelled option is treated as a file name. G2's AC-7 has to change this.
  Re-read it then; if AC-7 passes but two bare files still silently collapse to one, say so.
- 🆕 The G0 install wall-time and `Packages: +41` remain the only numbers I never re-derived (warm
  store, `node_modules/` already present). Not worth chasing; noted so it is not mistaken for verified.

## The worker's habits

- ✅ Accurate. Every G0 number I re-checked came back exactly as written, including the fixture
  measurements down to the line number of the unterminated quote.
- ✅ Quotes real output and says so when a clean result is *empty* output rather than inventing a
  success line (it did this for `tsc --noEmit`). Good instinct — keep expecting it.
- ✅ Records rather than fixes when something is outside the goal (it found the goal brief's
  environment block wrong and filed it as an incidental finding instead of editing the brief).
- 🆕 Held position and re-reported instead of racing ahead to G1 when the first completion was not
  acknowledged. It did not touch the tree on that second turn — I diffed and confirmed.
- ✅ Stops cleanly at the goal boundary. G1 built no error paths even though the code was inches from
  them, and filed the gap as a finding instead. I probed ten edge cases myself and every one is still
  unhandled exactly as claimed — no quiet half-implementation.
- ✅ Reports its own failures unprompted: it volunteered that the first `pnpm lint` run failed on two
  over-long lines, said it reformatted, and **re-ran every AC command against the reformatted source**
  so the quoted output still matches the file on disk. That last step is the one most workers skip.
- 🆕 Reaches for AC evidence that actually discriminates. For the AND in AC-4 it chose a clause pair
  giving **zero** rows where one clause alone matches — a result that OR could not produce. Expect and
  reward this; a worker showing only the 1-row case has not proven AND.

## Proven along the way — later goals may cite

- ✅ `basic.csv`: header `id,name,city,amount`, 5 data records, uniformly 4 fields. The Osaka rows are
  `1,Aiko,Osaka,1200` and `3,Chika,Osaka,450` — so **`--where city=Osaka` is 2 rows and the amount sum
  is 1650**, and the full file sums to 4750. I re-derived this from the raw file, so G1's AC-4, AC-5
  and AC-6 have a known-good target.
- ✅ `quoted.csv`: header `id,name,note`, 3 data records, uniformly 3 fields, covering all four quoting
  features between them — record 1 an embedded comma *and* a doubled quote (`Suzuki, Taro` /
  `says "hello"`), record 2 a line break inside a quoted field (the record starts on line 3 and ends on
  line 4), record 3 an empty quoted field (`3,"",plain`).
- ✅ `broken.csv`: header `id,name` (2 fields), exactly one complete data record `1,ok`, then line 3
  `2,"never closed` opens a quote that is never closed and swallows the rest of the file. **Line 3 is
  the number G2's AC-9 must see** in the error message.
- ✅ The three fixtures are untracked-clean in git and byte-identical to what was given.
- ✅ **`pnpm run` propagates a non-zero exit code faithfully, including 2.** I verified this directly
  rather than assuming: a probe script calling `process.exit(2)` returned 2 both as `node` and through
  `pnpm`. So G2 may judge AC-9's exit-2 rows with `pnpm csvq`; no need to bypass pnpm. (I added the
  probe script to `app/package.json`, then restored the file and confirmed it byte-identical.)
- ✅ G1's tool output, all re-run by me: `basic.csv` round-trips **byte-identical** to the fixture
  (106 bytes in, 106 out); `--select` honours the option's order, not the file's (`--select city,name`
  reverses the columns); `--where city=Osaka` → 2 rows, `+ --where name=Aiko` → 1, `+ --where name=Ben`
  → 0 while `--where name=Ben` alone → 1; `--count` → 5 and 2; `--sum amount` → 4750 and 1650 filtered.
- ✅ `--format json` on quoted.csv prints all four quoting features in one output: `"Suzuki, Taro"`,
  `says \"hello\"`, `"two\nlines"`, and `"name": ""`.
- 🆕 **G2's starting line, measured by me at the end of G1** — every one of these is currently wrong
  and is exactly what G2 must fix, so they double as a checklist: unknown `--where` column → silently
  0 rows at exit 0; unknown `--select` column → a header with empty cells at exit 0; `--sum name` →
  `NaN` at exit 0; `--format xml` → silently falls back to csv at exit 0; `--count --format json` →
  prints `5` instead of refusing; `broken.csv` → prints a mangled record at exit 0 instead of failing;
  a missing file, an unknown option and `--select` with no value → an uncaught Node stack trace at
  exit 1, not a named message at the contracted code.

## What the bus verified itself

### Review 1 — G0

- Re-ran `pnpm test` (`Test Files 1 passed (1)`, `Tests 1 passed (1)`), `pnpm lint`
  (`Checked 2 files in 3ms. No fixes applied.`) and `pnpm typecheck` (silent, exit 0). All three match
  the ledger exactly.
- `git diff specs/csvq/SCOPE.md` shows one changed line, DRAFT → `FROZEN 2026-09-29`, nothing else.
- `git status --short -- app/pnpm-workspace.yaml` and `-- app/fixtures/` are both empty: the red-line
  files are untouched. This is the runbook's own post-G0 check.
- Read all three fixtures raw with `cat -A` and re-derived every E4 number independently.
- `ls /tmp/csvq-*` → nothing; the three scratch files really are gone.
- `git status --short` repo-wide: every change is inside `app/` or `specs/csvq/`.

### Review 2 — G1

- Re-ran all six AC commands myself and got byte-for-byte what the ledger quotes, plus the extra
  controls I asked for (`--select city,name`, `--where name=Ben` alone).
- Re-ran `pnpm test` (`Tests  10 passed (10)`), `pnpm lint` (`Checked 4 files in 7ms. No fixes
  applied.`) and `pnpm typecheck` (silent, exit 0) against the tree as it stands.
- Read `src/csv.ts`, `src/cli.ts` and `test/csv.test.ts` in full. The five required dialect cases are
  present as five separate tests, and CRLF is built inline because no fixture has it, as instructed.
- Confirmed `app/test/placeholder.test.ts` is gone and `test/` holds only `csv.test.ts`.
- `git status --short` for `app/pnpm-workspace.yaml` and `app/fixtures/` is empty; `ls /tmp/csvq-*`
  finds nothing; every change is inside `app/` or `specs/csvq/`.
- Probed ten unhandled edge cases to fix G2's starting point (recorded above under "Proven").

### Review 3 — G2 (final)

- Re-ran AC-7 through AC-10 myself with exit codes: unknown option → 1, unknown column in all three
  options → 1 each naming the column, missing file → 2, broken.csv → 2 naming **line 3**, json → an
  array of objects, `--count --format json` → 1. All match the ledger.
- Checked the frozen clauses that have no AC row and found every one implemented: `--sum name` → 2
  with `"Aiko" on line 2`, `--count --sum` → 1, `--format xml` → 1, `--select` with no value → 1, no
  file → 1, `--help` → 0, and a ragged record I built myself → 2 with `record on line 3 has 3 fields,
  but the header has 2`.
- **Ran the whole G1 surface again as a regression check** — printing, `--select` order, the AND with
  zero rows, `--count`, both sums, json on quoted.csv. G2's error plumbing broke nothing.
- Verified each of the nine AS-BUILT differences against the tool rather than the table: D2 (two files
  → 1), D3 (`--help` wins over a forbidden combination → 0), D5 (`--where city` → 1), D6 (empty cell
  under `--sum` → 2, naming the line), D9 (malformed command naming a missing file → 1, not 2).
- Generated my own 10,000-record file and timed it independently (see the AC-11 ruling below).
- Re-verified all 14 README examples with my own extractor: **14 match, 0 mismatch**, error blocks
  and their exit codes included.
- `pnpm test` → `Tests  39 passed (39)` across 2 files; lint `Checked 5 files`; typecheck exit 0.
- Confirmed the handover's `.gitkeep` claim, which `ls -R` had hidden from me: `app/src/.gitkeep` and
  `app/test/.gitkeep` do still exist and are tracked. The worker was right.
- Red lines still clean, no file over 100 KB under `app/`, `ls -d /tmp/csvq-*` finds nothing.

## Rulings the bus made

- 🆕 **AC-11 is judged on the tool's runtime, not on the invocation (final ruling, G2).** The worker
  reported both numbers instead of the flattering one and asked me to decide. I measured it myself:
  bare `node` median 149 ms; through `pnpm` median 1284 ms — but `pnpm` on the **5-record** fixture
  costs 1290 ms, i.e. the same. The launcher toll is constant and independent of the data, so under
  the invocation reading **no implementation could ever pass on this machine** — an empty program
  already costs more than 1 s. A criterion no implementation can satisfy is not measuring the
  implementation. PASS upheld. Any future performance AC should name what it is measured through.
- 🆕 **CRLF inside a quoted field normalises to LF.** SCOPE.md fixes "output uses LF" but is silent on
  what a CRLF *within* a quoted field becomes on the way in. G1 normalises it, so a CRLF file and the
  same LF file parse equal. I accepted this at the G1 review: it is the only reading consistent with
  the LF-output rule, and it resolves an ambiguity rather than changing a term. It is a reading note,
  not a contract change — but G2's AS-BUILT must state it explicitly so it stops being implicit.
- 🆕 **The goal brief's "facts already verified" block is not evidence.** It was written on a different
  machine and three of its environment claims are false here. Observation beats the brief; a worker
  that contradicts the brief *with output* is right to. Do not reject on that ground.

## Watch closely

The run is closed: G0, G1 and G2 all PASS, verdict DONE at review 3. Nothing is pending for a bus.
What is left is the human's, per the runbook: commit, record the run in `examples/toy-run/README.md`,
then `rm specs/csvq/.bus-armed specs/csvq/.gate-armed`. If a session is ever resumed against this
directory, these are the live questions, none of them blocking:

- 🔴 Handover items 1 and 2 are about the *kit*, not csvq: `goal-brief.md`'s "facts already verified"
  block describes a different machine, and a performance AC judged through `pnpm` measures the
  launcher. Both would mislead the next run of this pack and are worth fixing in the pack itself.
- 🆕 Handover item 3 asks the human to confirm D2 and D6, the two AS-BUILT readings that could
  defensibly have gone the other way. They are decided and tested, not open — but they were decided
  by the worker, not by the frozen contract.
- 🆕 Nothing is committed. Three commit messages are proposed in the ledger and have never been run.
