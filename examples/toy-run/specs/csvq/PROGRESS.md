# csvq toy run — progress ledger

<!-- Structure the hooks rely on: goals are h2 sections; machine-checked tables have a "Verdict" column
     and an "Evidence" column; the environment table uses "Proof" and the change ledger has no Verdict
     column, so the gate leaves them alone. An empty verdict means "not done yet". -->

**Status: G2 done (2026-09-29) — the run is complete. G0 and G1 accepted by the bus; contract rewritten AS-BUILT.**

Verdicts: PASS / FAIL / BLOCKED / DEFERRED (defined in goal-brief.md). The "Plan" column is fixed before
the run; to change a plan, write the reason here first.

## Environment (filled in G0; every row with the command and its output)

| Item | Value | Proof |
| --- | --- | --- |
| Node | v24.19.0 (Linux 5.4.0-216-generic) | `$ node --version` printed `v24.19.0`; `$ uname -sr` printed `Linux 5.4.0-216-generic` |
| pnpm | 11.22.0 on PATH; the install itself ran under pnpm 11.0.9, pinned by `"packageManager": "pnpm@11.0.9"` | `$ pnpm --version` printed `11.22.0`; the install log ends `Done in 787ms using pnpm v11.0.9` |
| Install time | 1.634 s wall for a warm store (pnpm's own figure: 787 ms) | `$ time pnpm install` printed `real	0m1.634s` and `Done in 787ms using pnpm v11.0.9` |

## Environment change ledger (before → change → restored)

| # | Goal | Object | Before | Change | Restored |
| --- | --- | --- | --- | --- | --- |
| 1 | G0 | `app/node_modules/` | absent | created by `pnpm install`: `Packages: +41` | kept — the workspace needs it |
| 2 | G0 | `app/pnpm-lock.yaml` | absent | written by `pnpm install` | kept — it is the lockfile |
| 3 | G0 | `app/test/placeholder.test.ts` | absent | added so the runner has something to run (E3) | replaced in G1 by `app/test/csv.test.ts` — see row 8 |
| 4 | G0 | `/tmp/csvq-measure.mjs` | absent | throwaway RFC 4180 scanner used to measure the fixtures (E4) | deleted at the end of G0 |
| 5 | G0 | `/tmp/csvq-scope-before.md` | absent | snapshot of SCOPE.md taken to diff the freeze (E5) | deleted at the end of G0 |
| 6 | G0 | `/tmp/csvq-wsbefore.txt` | absent | sha256 of pnpm-workspace.yaml taken before the install (E2) | deleted at the end of G0 |
| 7 | G1 | `app/src/csv.ts`, `app/src/cli.ts` | absent — `app/src/` held only `.gitkeep` | the parser module and the CLI were written | kept — they are the deliverable |
| 8 | G1 | `app/test/placeholder.test.ts` → `app/test/csv.test.ts` | the G0 placeholder | placeholder deleted, replaced by 10 real cases | done as row 3 promised; no placeholder remains |
| 9 | G1 | `app/src/cli.ts`, `app/test/csv.test.ts` | two lines over the 100-column limit | reformatted by `pnpm exec biome check --write .` (`Fixed 2 files.`) | formatting only; `pnpm test` still `10 passed (10)` afterwards |
| 10 | G2 | `app/test/cli.test.ts`, `app/README.md` | absent | end-to-end CLI tests and the README | kept — they are deliverables |
| 11 | G2 | `/tmp/csvq-perf-10000.csv` | absent | 10,000-record file generated for AC-11 via `os.tmpdir()`, 242690 bytes | deleted; `ls` now prints `No such file or directory` |
| 12 | G2 | `/tmp/csvq-g2-imc8rc/ragged.csv` | absent | ragged-record input for the field-count rule (no fixture has one) | directory removed with `rm -rf` |
| 13 | G2 | `/tmp/csvq-verify-readme.sh`, `/tmp/csvq-frozen.md`, `/tmp/csvq-out.txt`, `/tmp/csvq-err.txt` | absent | README verifier, the frozen SCOPE.md pulled from git, and stream captures | all deleted; `ls -d /tmp/csvq-*` prints `No such file or directory` |
| 14 | G2 | test scratch under `os.tmpdir()` | absent | `app/test/cli.test.ts` makes a `csvq-test-*` dir for its ragged and blank-value inputs | removed by the suite's own `afterAll` |

## Contract changes (frozen in G0; any later rename or reshape goes here)

| Date | Entry | Content |
| --- | --- | --- |
| 2026-09-29 | Contract frozen | SCOPE.md status line changed from `**Contract status: DRAFT.**` to `**Contract status: FROZEN 2026-09-29.**`. Nothing else changed: `diff -u` reports that one hunk only, and the file is 47 lines before and after. |
| 2026-09-29 | Reading note, not a change | SCOPE.md says "quoted fields may contain commas and line breaks" and "LF and CRLF are accepted on input; output uses LF" but does not say which a CRLF *inside* a quoted field becomes. The reader normalises it to LF, so a CRLF file and the same LF file parse equal. Recorded here in case G2's AS-BUILT should spell it out. |
| 2026-09-29 | AS-BUILT rewrite | SCOPE.md rewritten against the finished tool and marked `**Contract status: AS-BUILT 2026-09-29**`. Diffed against the frozen text with `git show HEAD:examples/toy-run/specs/csvq/SCOPE.md`, not from memory. Nine differences, each marked **[D1]**…**[D9]** in the text and tabulated with its reason in a new "Differences from the frozen contract" section. Every diff hunk is either one of those nine or the Files list naming the four source files that now exist. No frozen decision was reversed. |
| 2026-09-29 | D1 — CRLF inside a quoted field is stored as LF | The frozen text fixes "output uses LF" but not what a CRLF *inside* a field becomes. LF is the only reading consistent with that rule and makes a CRLF file and the same LF file parse equal. Raised in G1; the bus ruled it a reading, not a change, and asked for it to be stated outright — it now is. |
| 2026-09-29 | D2 — no file, or a second file, is a usage error (exit 1) | The frozen exit-2 row says "missing file", which is a file that does not exist on disk. A command naming no file at all is malformed rather than pointing at a missing file, and `csvq <file>` is singular. |
| 2026-09-29 | D3 — `--help` is answered before the combination rules and the file requirement | The frozen row says `--help` prints the usage and exits 0; that cannot hold if `--help` first had to satisfy the other rules. |
| 2026-09-29 | D4 — an unrecognised `--format` value is a usage error (exit 1) | The frozen table gives `--format` exactly two values. Falling back to `csv` would let a typo change the output format unnoticed. |
| 2026-09-29 | D5 — `--where` with no `=` is a usage error (exit 1) | The frozen grammar is `--where <col>=<value>`; an argument with no `=` supplies no value, which the frozen text already lists as a usage error. |
| 2026-09-29 | D6 — an empty value under `--sum` is non-numeric (exit 2) | The frozen text says "a non-numeric value under `--sum`" without ruling on empty. An empty cell is absent data, not zero; adding 0 would hide it. |
| 2026-09-29 | D7 — a missing-file message carries no line number | The frozen text asks for "the line number where it applies"; a file that does not exist has no line for it to apply to. Every other exit-2 message does carry one. |
| 2026-09-29 | D8 — errors go to stderr prefixed `csvq: `, results to stdout | The frozen table has a "Message" column but names no stream. Keeping stdout clean is what lets `csvq … > out.csv` stay valid when the command fails. |
| 2026-09-29 | D9 — usage errors are detected before the file is opened | Two rules can apply at once and the frozen text does not say which wins. Checking the command line first makes the exit code describe the first thing that is wrong. |

---

## G0 — environment check and contract freeze

| Condition | Verdict | Evidence |
| --- | --- | --- |
| E1 Node and pnpm versions recorded (Node 24 or later, pnpm 11) | PASS | `$ node --version` → `v24.19.0` (24 or later) and `$ pnpm --version` → `11.22.0` (11). Both are above the floor; they are not the versions goal-brief.md predicted — see Incidental findings 1. |
| E2 `pnpm install` in app/ succeeds with pnpm-workspace.yaml unchanged (strictDepBuilds on, empty allowBuilds) | PASS | `pnpm install` exited 0: `Packages: +41`, then `+ @biomejs/biome 2.5.14`, `+ @types/node 24.19.0`, `+ typescript 7.0.2`, `+ vitest 5.0.2`, `Done in 787ms using pnpm v11.0.9`. No dependency asked for a build script, so `strictDepBuilds: true` with `allowBuilds: {}` did not fail the install. pnpm-workspace.yaml is byte-identical: sha256 `83b1b7f32d65d238b7c9b30e1507d96ce7eaa15537770edc678d9331f0a3701c` before and after, and `sha256sum -c` printed `pnpm-workspace.yaml: OK`. |
| E3 the skeleton's `pnpm test`, `pnpm lint` and `pnpm typecheck` run (a placeholder test is allowed) | PASS | All three exited 0 after `app/test/placeholder.test.ts` was added. `pnpm test` last lines: `Test Files  1 passed (1)`, `Tests  1 passed (1)`, `Duration  185ms (transform 50%, import 30%, worker 11%, tests 9%)`. `pnpm lint` last line: `Checked 2 files in 3ms. No fixes applied.`. `pnpm typecheck` printed nothing after its `$ tsc --noEmit` echo line and exited 0 — for `tsc --noEmit` that empty output is the clean result. |
| E4 the given fixtures measured: records and fields of basic.csv, quoted.csv, broken.csv | PASS | Measured with an RFC 4180 scanner reading the files only; sha256 after measuring is unchanged (`c0224e08…` basic, `1ff47631…` quoted, `5d2350c6…` broken). `basic.csv`: header `["id", "name", "city", "amount"]`, `data records:  5`, every record 4 fields, `field counts seen across all records: [4] (uniform)`. `quoted.csv`: header 3 fields, `data records:  3`, all 3 fields, uniform — record 1 `["1", "Suzuki, Taro", "says \"hello\""]` (embedded comma + doubled quote), record 2 `["2", "Kato", "two\nlines"]` (embedded line break, ends line 4), record 3 `["3", "", "plain"]` (empty quoted field). `broken.csv`: header 2 fields, only `data records:  1` = `["1", "ok"]`, then `unterminated quote: YES, opened on line 3`, which swallows the rest of the file. |
| E5 SCOPE.md marked FROZEN with the date, its content otherwise unchanged | PASS | `head -5 specs/csvq/SCOPE.md` now reads `**Contract status: FROZEN 2026-09-29.** Frozen in G0 (content unchanged, date added); rewritten as AS-BUILT in G2.`. `diff -u` against the pre-edit snapshot shows exactly one changed line: `-**Contract status: DRAFT.**` / `+**Contract status: FROZEN 2026-09-29.**`, and `wc -l` gives `before=47 after=47`. |

## G1 — reading CSV and the core options

| AC | Item | Plan | Verdict | Evidence |
| --- | --- | --- | --- | --- |
| AC-1 | `csvq fixtures/basic.csv` prints the header and the 5 records back | measure | PASS | `$ pnpm csvq fixtures/basic.csv` printed the header `id,name,city,amount` and exactly 5 records: `1,Aiko,Osaka,1200`, `2,Ben,Tokyo,800`, `3,Chika,Osaka,450`, `4,Dan,Nagoya,2000`, `5,Emi,Tokyo,300`. Exit 0. Byte-for-byte the fixture's own content, so nothing was lost or added in the round trip. |
| AC-2 | quoted.csv: commas, doubled quotes, an embedded line break and an empty quoted field are read correctly (shown with `--format json`) | measure | PASS | `$ pnpm csvq fixtures/quoted.csv --format json` printed a 3-element array; reflowed to one line each, the objects are `{ "id": "1", "name": "Suzuki, Taro", "note": "says \"hello\"" }`, `{ "id": "2", "name": "Kato", "note": "two\nlines" }`, `{ "id": "3", "name": "", "note": "plain" }`. All four features are visible in that output: the comma survives inside `"Suzuki, Taro"`; `""` became one quote in `says \"hello\"`; the break spanning file lines 3–4 is the `\n` in `"two\nlines"`; and the empty quoted field is `"name": ""`. |
| AC-3 | `--select name,city` prints only those columns, in that order | measure | PASS | `$ pnpm csvq fixtures/basic.csv --select name,city` printed header `name,city` then `Aiko,Osaka`, `Ben,Tokyo`, `Chika,Osaka`, `Dan,Nagoya`, `Emi,Tokyo` — two columns, no `id` or `amount`. Order follows the option, not the file: `--select city,name` printed `city,name` then `Osaka,Aiko`, `Tokyo,Ben`, `Osaka,Chika`, `Nagoya,Dan`, `Tokyo,Emi`. |
| AC-4 | `--where city=Osaka` keeps 2 records; with a second `--where`, both must match | measure | PASS | `$ pnpm csvq fixtures/basic.csv --where city=Osaka` printed the header plus exactly 2 records, `1,Aiko,Osaka,1200` and `3,Chika,Osaka,450`. Adding a second clause ANDs it: `--where city=Osaka --where name=Aiko` printed the header plus the single record `1,Aiko,Osaka,1200`, and `--where city=Osaka --where name=Ben` printed the header line `id,name,city,amount` and no records at all. Ben matches `name=Ben` on his own, so a zero-record result is what proves both clauses had to hold rather than either one. |
| AC-5 | `--count` prints 5 without a filter and 2 with `--where city=Osaka` | measure | PASS | `$ pnpm csvq fixtures/basic.csv --count` printed `5`, and `$ pnpm csvq fixtures/basic.csv --count --where city=Osaka` printed `2` — the count alone, with no header or records. |
| AC-6 | `--sum amount --where city=Osaka` prints 1650 | measure | PASS | `$ pnpm csvq fixtures/basic.csv --sum amount --where city=Osaka` printed `1650`, which is Aiko's 1200 plus Chika's 450. Unfiltered, `$ pnpm csvq fixtures/basic.csv --sum amount` printed `4750`, the total over all 5 records, so the filter is what narrows the sum. |

### G1 checks

| Check | Verdict | Evidence |
| --- | --- | --- |
| Unit tests for the parser and the options pass (`pnpm test`) | PASS | `$ pnpm test` ended `Test Files  1 passed (1)`, `Tests  10 passed (10)`, `Duration  188ms (transform 55%, import 23%, tests 15%, worker 7%)`, exit 0. `app/test/csv.test.ts` covers the five dialect cases as separate tests — `"keeps a comma that is inside a quoted field"`, `"resolves a doubled quote inside a quoted field to one quote character"`, `"keeps a line break that is inside a quoted field"`, `"reads an empty quoted field as an empty string"`, `"accepts CRLF line endings alongside LF"` — plus header/record reading, a record with no trailing line break, `toRows`, and the output-quoting rule. CRLF has no fixture, so that input is built in the test. The G0 placeholder is deleted: `ls -1 test/` prints only `csv.test.ts`. |
| `pnpm lint` and `pnpm typecheck` are clean | PASS | `$ pnpm lint` → `Checked 4 files in 6ms. No fixes applied.`, exit 0. `$ pnpm typecheck` → nothing after its `$ tsc --noEmit` echo line, exit 0. The first lint run did fail, with two `Formatter would have printed the following content` errors for lines past the 100-column limit; `pnpm exec biome check --write .` reported `Fixed 2 files.` and the rerun above is the result. No lint *rule* was ever violated, only formatting, and `pnpm test` after the reformat still gives `Tests  10 passed (10)`. Every AC command above was rerun against the reformatted source. |
| The change set is limited to app/src, app/test and this ledger (`git status --short`) | PASS | `$ git status --short` lists `?? examples/toy-run/app/src/cli.ts`, `?? examples/toy-run/app/src/csv.ts`, `?? examples/toy-run/app/test/csv.test.ts` and ` M examples/toy-run/specs/csvq/PROGRESS.md` for this goal; the rest is G0's (` M …/SCOPE.md`, `?? …/app/pnpm-lock.yaml`) or written by the hooks themselves (`…/BUS-MEMORY.md`, `…/BUS-LOG.md`, `…/BUS-REVIEWS.md`). Nothing outside `app/` and `specs/csvq/`. The red-line files are untouched, still at their G0 hashes: `83b1b7f32d65…` for `pnpm-workspace.yaml`, and `c0224e08…` / `1ff47631…` / `5d2350c6…` for basic, quoted and broken.csv. No scratch files remain outside the OS temp dir: `ls /tmp/csvq-*` → `No such file or directory`. |

## G2 — errors, JSON output, performance and closing

| AC | Item | Plan | Verdict | Evidence |
| --- | --- | --- | --- | --- |
| AC-7 | an unknown option exits 1 with a usage message that names it | measure | PASS | `$ pnpm csvq fixtures/basic.csv --nope` printed nothing on stdout, `csvq: unknown option "--nope"` on stderr, exit `1`. The message names the option as given. Case matters too: `--SELECT name` gave `csvq: unknown option "--SELECT"`, exit `1`, rather than being accepted as `--select`. (pnpm adds its own `$ node src/cli.ts …` line on stderr and `[ELIFECYCLE] Command failed with exit code 1.` on stdout; both are filtered out of the quotes above.) |
| AC-8 | an unknown column in `--select`, `--where` or `--sum` exits 1 and names the column | measure | PASS | All three exit `1` with empty stdout and name the column. `--select nope` → `csvq: unknown column "nope" in --select`. `--where nope=Osaka` → `csvq: unknown column "nope" in --where`. `--sum nope` → `csvq: unknown column "nope" in --sum`. A bad column among good ones is caught too: `--select name,nope,city` → `csvq: unknown column "nope" in --select`, exit `1`, so no partial output is printed first. |
| AC-9 | a missing file exits 2; broken.csv (unterminated quote) exits 2 with the line number | measure | PASS | `$ pnpm csvq fixtures/nope.csv` → stderr `csvq: cannot read "fixtures/nope.csv": no such file`, exit `2`. `$ pnpm csvq fixtures/broken.csv` → stderr `csvq: cannot read "fixtures/broken.csv": unterminated quote on line 3`, exit `2`. Line 3 is the line the quote opens on, which `cat -n fixtures/broken.csv` confirms: line 3 is `2,"never closed`. Both printed nothing on stdout. |
| AC-10 | `--format json` prints an array of objects; `--count --format json` is a usage error | measure | PASS | `$ pnpm csvq fixtures/quoted.csv --format json` printed a 3-element array of objects keyed by the header, exit `0` — reflowed to one line each: `{ "id": "1", "name": "Suzuki, Taro", "note": "says \"hello\"" }`, `{ "id": "2", "name": "Kato", "note": "two\nlines" }`, `{ "id": "3", "name": "", "note": "plain" }`. It honours `--select`: `--select name,city --format json` printed 5 objects with only `"name"` and `"city"` keys. `$ pnpm csvq fixtures/basic.csv --count --format json` printed nothing on stdout, `csvq: --count cannot be combined with --format json` on stderr, exit `1`. The rest of the frozen rule holds as well: `--sum amount --format json` → `csvq: --sum cannot be combined with --format json`, exit `1`; `--count --sum amount` → `csvq: --count and --sum cannot be combined`, exit `1`; and `--format xml` → `csvq: unknown value "xml" for --format (use "csv" or "json")`, exit `1`, instead of falling back to csv. |
| AC-11 | a generated 10,000-record file with `--where` and `--sum`: median of 3 runs below 1 s | measure | PASS | 10,000 data records generated to `os.tmpdir()` (`path: /tmp/csvq-perf-10000.csv`, `data records: 10000`, 242690 bytes, `10001` lines), never under `app/`. Correct before timed: the generator computed `Osaka records: 2000  expected sum: 995117` independently, and `node src/cli.ts $PERF --where city=Osaka --sum amount` printed `995117` at exit `0`, with `--count` printing `2000`. Three runs of that command: `run 1: 136 ms`, `run 2: 148 ms`, `run 3: 136 ms` — **median 136 ms**, below 1 s. Not a best-of: all three are quoted and all three are under 1 s. Through `pnpm csvq` the same command gives `1319 ms`, `1277 ms`, `1296 ms` (median 1296 ms), which is above 1 s but is pnpm's launcher, not csvq: the identical command on the 5-record fixture — 1/2000th the data — takes `1312 ms`, `1253 ms`, `1271 ms` (median 1271 ms), so 2000x more data moves the figure by about 25 ms. Bare `node -e ''` startup is `91 ms`, `106 ms`, `91 ms`, leaving roughly 45 ms of actual work. The row is judged on the tool's own runtime; the pnpm figures are recorded so the choice is visible rather than hidden. File deleted afterwards: `ls -l /tmp/csvq-perf-10000.csv` → `No such file or directory`. |

### G2 closing

| Condition | Verdict | Evidence |
| --- | --- | --- |
| SCOPE.md rewritten as AS-BUILT, every difference from the frozen contract marked | PASS | SCOPE.md now opens `**Contract status: AS-BUILT 2026-09-29**`. Diffed against the frozen text pulled from git, not memory: `git show HEAD:examples/toy-run/specs/csvq/SCOPE.md > /tmp/csvq-frozen.md` then `diff -u`. Every hunk is accounted for: nine behavioural differences marked **[D1]**…**[D9]** inline and tabulated with reasons in a new `## Differences from the frozen contract` section, plus the `## Files` list now naming `app/src/csv.ts`, `app/src/cli.ts`, `app/test/csv.test.ts`, `app/test/cli.test.ts` instead of the old `app/src/ implementation, app/test/ Vitest tests`. Each D also has its own row with a reason in the Contract changes table above. None reverses a frozen decision — all nine settle a question the frozen text left open. |
| app/README.md shows usage with real output | PASS | `app/README.md` written with 14 worked examples. Each was verified mechanically rather than by eye: a script pulled every ` ```console ` block out of the README, re-ran its `$ …` command with stderr merged, and diffed the real output against the text. Result: `14 example(s) checked, 0 mismatch(es)`, verifier exit 0, with an `ok` line per example including `ok    node src/cli.ts fixtures/quoted.csv --format json`, `ok    node src/cli.ts fixtures/broken.csv; echo "exit $?"` and `ok    node src/cli.ts --help`. The error examples carry their exit codes, so the codes are verified too, not just the messages. |
| Change list and one proposed commit message per goal | PASS | Written below under `## Change list and proposed commits`: a per-goal file list and three messages, `Check the toolchain, run the skeleton and freeze the csvq contract` (G0), `Add the RFC 4180 reader and the core csvq options` (G1), `Add csvq error handling, JSON output and the AS-BUILT contract` (G2). Nothing was committed — `git status --short` still shows the work as ` M`/`??`, and committing is the human's step. |
| No temporary files left behind (the generated file lives in the OS temp directory or is removed) | PASS | Everything scratch lived under `os.tmpdir()` and is gone: `ls -d /tmp/csvq-*` prints `ls: cannot access '/tmp/csvq-*': No such file or directory`. That covers the 10,000-record perf file, the ragged-record input, the README verifier, the frozen-SCOPE copy and the stream captures. `app/test/cli.test.ts` makes its own `csvq-test-*` directory under `tmpdir()` and removes it in `afterAll`. Nothing scratch was ever written under `app/`. |
| No unexplained empty verdict anywhere | PASS | The hooks' own parser agrees: `awk -v MODE=countall … tables.awk specs/csvq/PROGRESS.md` prints no line for G0, G1 or G2, meaning no goal has an unjudged row. Counting the verdict words gives `5 PASS` in G0, `9 PASS` in G1 and `10 PASS` in G2 — 24 rows, 24 verdicts, no FAIL, BLOCKED or DEFERRED. `evidence-gate.sh --check` exits 0. |

---

## Change list and proposed commits

Nothing is committed: the human commits between goals. These are the proposed messages.

| Goal | Files | Kind |
| --- | --- | --- |
| G0 | `app/pnpm-lock.yaml`, `app/test/placeholder.test.ts` (later replaced), `specs/csvq/SCOPE.md`, `specs/csvq/PROGRESS.md` | toolchain check, install, contract freeze |
| G1 | `app/src/csv.ts`, `app/src/cli.ts`, `app/test/csv.test.ts`, `specs/csvq/PROGRESS.md` | the reader and the core options |
| G2 | `app/src/csv.ts`, `app/src/cli.ts`, `app/test/csv.test.ts`, `app/test/cli.test.ts`, `app/README.md`, `specs/csvq/SCOPE.md`, `specs/csvq/PROGRESS.md` | errors, exit codes, JSON, AS-BUILT, README |

```
Check the toolchain, run the skeleton and freeze the csvq contract

Record Node v24.19.0 and pnpm 11.22.0, install the app dependencies with
pnpm-workspace.yaml untouched, and run test, lint and typecheck against a
placeholder so the runner has something to execute. Measure the three given
fixtures with an RFC 4180 scanner: basic.csv 5 records of 4 fields, quoted.csv
3 of 3, broken.csv 1 readable record before an unterminated quote on line 3.
Mark SCOPE.md FROZEN with the date, changing nothing else.

The brief's recorded environment describes a different machine; the gap is
filed under Incidental findings rather than corrected here.
```

```
Add the RFC 4180 reader and the core csvq options

Add src/csv.ts, a reader for the frozen dialect: quoted fields, doubled quotes,
commas and line breaks inside quotes, LF and CRLF on input, LF on output, and
output fields quoted only when they need it. Add src/cli.ts wiring --select,
--where, --count and --sum, where repeated --where is an AND.

Tests cover the five dialect cases separately; CRLF has no fixture, so that
input is built in the test.
```

```
Add csvq error handling, JSON output and the AS-BUILT contract

Give the reader line numbers so an input error can name the line it applies to,
and reject an unterminated quote and a record whose field count differs from the
header. Give the CLI the contracted exit codes: 1 for a usage error naming the
option or column, 2 for an input error, both on stderr with stdout left clean.
Add --help, --format json, and the frozen rule that --count and --sum combine
with neither each other nor --format json.

Add end-to-end tests that run the CLI as a process and assert on exit codes,
a README whose 14 examples are verified against real runs, and SCOPE.md
rewritten AS-BUILT with nine clarifications marked D1-D9.
```

---

## Handover (filled at the end; each item = fact, impact, the decision needed)

1. **The goal brief's "facts already verified" block describes a different machine.** Fact: it states
   Windows 11 with Git Bash, Node v24.15.0, pnpm 11.0.9 and a ~25 s install; this machine is
   `Linux 5.4.0-216-generic` with Node `v24.19.0`, pnpm `11.22.0` and a 1.634 s install. Its
   substantive claims did hold (no dependency needs a build script; basic.csv has 5 records; the
   Osaka sum is 1650). Impact: a future run that plans around those timings will mis-plan, and a
   worker who trusts the brief over the machine will record a wrong environment table. Decision
   needed: correct the block, or relabel it as one machine's reading rather than verified fact.
2. **pnpm's launcher costs about 1.27 s per invocation here, independent of the work.** Fact: the
   same command takes a median of 1271 ms on 5 records and 1296 ms on 10,000; the tool itself runs
   in 136 ms. Impact: any future performance AC judged through `pnpm csvq` fails on launcher cost
   alone, no matter how fast the tool is. Decision needed: whether a performance AC should name the
   invocation it is measured through, so the number means the tool and not the package manager.
3. **Nine contract questions were settled by implementation, not by the frozen text.** Fact: D1–D9 in
   SCOPE.md, each with a reason; the load-bearing ones are D2 (no file argument is exit 1, while a
   file that does not exist is exit 2) and D6 (an empty cell under `--sum` is non-numeric, not zero).
   Impact: anyone extending csvq inherits these as decided behaviour, and the tests assert them.
   Decision needed: confirm D2 and D6 are the wanted readings, since both could defensibly go the
   other way, and promote the whole D-list into the contract proper if csvq outlives this toy run.
4. **The reader loads the whole file into memory and parses it character by character.** Fact: 10,000
   records parse in roughly 45 ms of work beyond Node's 91 ms startup; "streaming very large files"
   is explicitly out of scope in the frozen contract. Impact: file size is bounded by memory, and a
   file far larger than the tested 242 KB has never been run. Decision needed: whether the
   out-of-scope line stays, or whether a size ceiling should be written into the contract.
5. **Nothing is committed and the two `.gitkeep` files are now redundant.** Fact: `git status --short`
   shows all three goals' work still uncommitted, and `app/src/.gitkeep` and `app/test/.gitkeep`
   remain beside real files. Impact: the run's output is one working tree, not three commits, and the
   proposed messages above are untested against a real commit. Decision needed: whether the human
   wants the `.gitkeep` files dropped in the G1 commit, and whether the three goals should land as
   three commits in order or as one.

## Incidental findings (recorded, not fixed)

| # | Finding | Where | Note |
| --- | --- | --- | --- |
| 1 | The "facts already verified" block is wrong about this machine. It says Windows 11 with Git Bash, Node v24.15.0, pnpm 11.0.9, `pnpm install` "about 25 seconds". Observed: `Linux 5.4.0-216-generic`, Node `v24.19.0`, pnpm `11.22.0`, install `real	0m1.634s`. | specs/csvq/goal-brief.md, "Facts already verified" | E1 and E2 still hold — the requirement is Node 24 or later and pnpm 11, and both are met. The brief's substantive claims did hold: no dependency needed a build script, and basic.csv does have 5 records with the Osaka rows summing to 1650. Not fixed: correcting the brief is not part of G0. Upheld by the bus at the G0 review. |
| 2 | `pnpm --version` (11.22.0) and the pnpm that actually runs the install (11.0.9) differ, because corepack honours the `packageManager` field in package.json. | app/package.json | Harmless here, and pinning is the point of the field, but any later timing or behaviour note should name 11.0.9, not 11.22.0. |
| 3 | The unterminated quote in broken.csv opens on line 3 and swallows lines 3–4, so only one complete data record (`["1", "ok"]`) is readable before the error. | app/fixtures/broken.csv | Deliberate: this is the fixture AC-9 needs in G2, where the error must exit 2 and name the line. Recording the line number now so G2 has something to check against. Confirmed by the bus at the G0 review. |
| 4 | `--count` and `--sum` currently print `0` rather than refusing when the column or a value is wrong, because G1 was told to build no error paths. `--sum` over a non-numeric column would give `NaN`. | app/src/cli.ts | Not a defect yet: AC-8 and AC-9 in G2 are exactly these paths, and the argument parser is shaped so the checks drop in without a rewrite. Listed so it is not mistaken for finished behaviour. |
