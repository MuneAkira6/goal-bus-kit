
## G0 — review #1, full reply (2026-09-29 17:43:53)

**Review 1 — G0 — verdict PASS.**

I checked all five rows against the tree rather than reading them, and every number the worker reported came back the same.

What I ran: `node --version` → `v24.19.0`, `pnpm --version` → `11.22.0`, `uname -sr` → `Linux 5.4.0-216-generic` (E1 — above the Node 24 / pnpm 11 floor). `pnpm test` → `Test Files  1 passed (1)`, `Tests  1 passed (1)`; `pnpm lint` → `Checked 2 files in 3ms. No fixes applied.`; `pnpm typecheck` → silent at exit 0 (E3 — all three reproduced, and the worker was right to state plainly that silence *is* the clean result for `tsc --noEmit` instead of quoting a success line that doesn't exist). `git diff -- specs/csvq/SCOPE.md` shows exactly one changed line, `DRAFT` → `FROZEN 2026-09-29`, and nothing else (E5). For E2 the requirement I can still test is the one that matters: `git status --short -- app/pnpm-workspace.yaml` is empty, so the install left the supply-chain settings byte-identical — the runbook's own post-G0 check. `git status --short -- app/fixtures/` is likewise empty, so the given fixtures are untouched.

E4 I re-derived from scratch with `cat -A` on the raw files rather than trusting the scanner. `basic.csv`: header `id,name,city,amount`, 5 data records, uniformly 4 fields. `quoted.csv`: header of 3, 3 data records of 3, and between them all four quoting features — record 1 carries an embedded comma *and* a doubled quote, record 2's quoted field spans lines 3–4, record 3 is the empty quoted field. `broken.csv`: 2-field header, one complete record `1,ok`, then line 3 `2,"never closed` opens a quote that is never closed. The worker's line-3 claim is exactly right, and filing it now was the correct instinct — G2's AC-9 has to name that number. While I was in `basic.csv` I read the Osaka rows off directly: `1,Aiko,Osaka,1200` and `3,Chika,Osaka,450`, so `--where city=Osaka` is 2 rows summing to 1650. G1's AC-4 through AC-6 now have a target I derived myself rather than one copied from the brief.

Leftovers and red lines are clean: `ls /tmp/csvq-*` finds nothing, so the three scratch files really were deleted, and repo-wide `git status --short` puts every change inside `app/` or `specs/csvq/`. No contract drift — the only SCOPE.md edit is the status line, it is logged in the Contract changes table with its reason, and no option name, exit code or quoting rule moved.

Two things I am not rubber-stamping so much as declining to chase. The install's `1.634s` and `Packages: +41` are the only figures I could not re-derive — the store is warm and `node_modules/` already exists, so re-running proves nothing about the original. Everything else in G0 I reproduced, and E2's substance (workspace unchanged, no build script demanded) I confirmed directly. Second, `pnpm lint` says "Checked 2 files" with one real source file present; harmless now, but I have noted it to re-read as files are added.

On the worker's incidental finding 1, my ruling is that it is right and the brief is wrong. The "facts already verified" block was written on the pack author's machine — it claims Windows 11, Node v24.15.0, pnpm 11.0.9 and a ~25 s install, and three of those are false here. Observation beats the brief. I have struck those entries from BUS-MEMORY.md and replaced them with what I measured; the proxy claim survives, since the proxy variables are in fact set. Finding 2 is also correct and worth carrying: corepack runs the install under the pinned 11.0.9, so version-sensitive notes must name that, not the 11.22.0 on PATH.

One environment fact I established for G1 that nobody has written down yet: Node here runs `.ts` files directly via native type stripping — I put a typed throwaway script through `node` and it worked. That matters because `package.json` already wires `"csvq": "node src/cli.ts"` and the `bin` entry at a `.ts` file. There is no build step in this project and none should be added.

Proceeding to G1.

BUS-VERDICT: PASS
BUS-NEXT-BEGIN
G0 is accepted. All five rows passed; I re-ran your three checks, re-derived every fixture measurement from the raw files, and confirmed pnpm-workspace.yaml and the fixtures are untouched. Your reading of broken.csv (unterminated quote opening on line 3) is correct and G2 will be judged against it. Your incidental finding 1 is upheld: goal-brief.md's "facts already verified" block was written on a different machine and is wrong about this one. Trust what you observe over what the brief predicts, and keep filing such gaps as findings rather than editing the brief.

Start G1: the RFC 4180 reader and the core options, rows AC-1 through AC-6 plus the three G1 checks in PROGRESS.md.

Work in this order.

1. Build the reader first, with unit tests before the CLI. Put the parser in app/src/ as its own module and give it Vitest tests in app/test/ that cover, as separate cases: a field containing a comma inside quotes; a doubled quote inside a quoted field resolving to one quote character; a quoted field containing a line break; an empty quoted field; and CRLF line endings accepted alongside LF. The fixtures give you the first four for free — quoted.csv record 1 is "Suzuki, Taro" with note `says "hello"`, record 2's note spans lines 3-4, record 3 is `3,"",plain`. CRLF is in the contract but not in any fixture, so build that input inline in the test. Replace app/test/placeholder.test.ts as part of this; it exists only so G0 had something to run.

2. Then the CLI at app/src/cli.ts, wiring --select, --where, --count and --sum. Repeated --where is an AND: every one must match.

3. Judge each AC row by running the CLI and quoting what it printed. Unit tests passing is not evidence for an AC row — app/src/ was empty until now, so I will read these rows as claims about the tool's actual output. Run it as `pnpm csvq <args>` from app/ (the script is `node src/cli.ts`). Expected results I derived myself from basic.csv, so you can check against them: the file has 5 data records; --where city=Osaka keeps exactly 2 (Aiko 1200 and Chika 450); --sum amount with that filter is 1650; --sum amount with no filter is 4750. For AC-4's second half use a pair like --where city=Osaka --where name=Aiko, which must keep 1 record, and show a non-matching combination too so the AND is visibly doing work. For AC-2 use --format json on quoted.csv and quote the output, since that is how the row asks to see the parse; implement only as much of json output as AC-2 needs to display rows. Do not build out the rest of --format, the error paths, exit codes or the performance check — those are G2 rows and starting them now is scope creep I will reject.

4. Environment notes that will save you time. Node here runs .ts directly by stripping types, so there is no build step and you must not add one. tsconfig.json sets verbatimModuleSyntax and allowImportingTsExtensions, so write intra-project imports with the explicit .ts suffix and use `import type` for type-only imports, or typecheck will fail. Biome's lint preset is "recommended" over src/** and test/**. The install runs under pnpm 11.0.9 via corepack regardless of the 11.22.0 on PATH. Proxy variables are set in this environment: do not unset, change or print them.

5. Before you report complete: `pnpm test`, `pnpm lint` and `pnpm typecheck` all green, quoted in the G1 checks table; `git status --short` showing the change set confined to app/src, app/test and specs/csvq; pnpm-workspace.yaml and app/fixtures/ untouched; no scratch files left outside the OS temp directory; and no empty verdict in the G1 section. Every row gets PASS, FAIL, BLOCKED or DEFERRED with the command and its real output beside it.

Budget: about 25 turns. If the parser fights you on a specific quoting case, record that row FAIL with the input and the wrong output and keep going rather than stalling on it. If something outside your reach blocks you — a red-line file you would have to change, or a contract question SCOPE.md does not answer — stop and report BLOCKED with the reason and what you tried; do not work around it.
BUS-NEXT-END

## G1 — review #2, full reply (2026-09-29 17:52:01)

**Review 2 — G1 — verdict PASS.**

I re-ran all six AC commands and all three checks against the tree rather than reading the ledger, and every figure came back identical.

The ACs. `pnpm csvq fixtures/basic.csv` printed the header and exactly 5 records; I checked the round-trip claim properly by diffing the output against the fixture — 106 bytes in, 106 out, no difference (AC-1). `--format json` on quoted.csv showed all four quoting features in one output: `"Suzuki, Taro"` keeps its comma, `says \"hello\"` is one quote where the file has two, `"two\nlines"` is the break spanning file lines 3–4, and `"name": ""` is the empty quoted field (AC-2). `--select name,city` printed those two columns only, and `--select city,name` reversed them, so order follows the option rather than the file (AC-3). `--count` gave 5 and 2; `--sum amount` gave 4750 unfiltered and 1650 with the Osaka filter, matching the numbers I derived from the raw fixture at G0 before any code existed (AC-5, AC-6).

AC-4 deserves specific credit. The worker picked `--where city=Osaka --where name=Ben`, which returns zero records, and I confirmed the control: `--where name=Ben` alone returns Ben's row. A zero-row result where one clause matches on its own is a result OR cannot produce, so that single case actually proves the AND. The 1-row case with `name=Aiko` would have been consistent with either reading. That is the difference between evidence and illustration, and it was the worker's own choice.

The checks. `pnpm test` → `Tests  10 passed (10)`; `pnpm lint` → `Checked 4 files in 7ms. No fixes applied.`; `pnpm typecheck` silent at exit 0. I read all three source files in full. The five dialect cases I asked for are five separate tests, not one lumped assertion, and CRLF is built inline in the test because no fixture carries it — including a CRLF break *inside* a quoted field, which is the interesting half. The G0 placeholder is genuinely deleted; `test/` holds only `csv.test.ts`. Red lines hold: `git status --short` is empty for both `app/pnpm-workspace.yaml` and `app/fixtures/`, `ls /tmp/csvq-*` finds nothing, and every change sits inside `app/` or `specs/csvq/`.

The lint failure the worker volunteered is worth naming, because of what it did next. Two lines ran past the 100-column limit, `biome check --write` reformatted them — and it then re-ran every AC command against the reformatted source, so the output quoted in the ledger matches the file on disk rather than a version that no longer exists. That is the step most likely to be skipped, and skipping it quietly invalidates every quoted line.

On the contract question: I am ruling, not escalating. SCOPE.md fixes "output uses LF" but says nothing about what a CRLF *inside* a quoted field becomes on the way in. Normalising it to LF is the only reading consistent with the output rule, and it makes a CRLF file and the same LF file parse equal. That resolves an ambiguity rather than moving a term, so "reading note, not a change" is the right classification and the row stands as written. G2's AS-BUILT must state it outright so it stops being implicit.

I did one thing beyond reading, and record it here since it touched a file: to be sure AC-9's exit codes are testable, I checked whether `pnpm run` mangles a non-zero exit. It does not — a probe script calling `process.exit(2)` returns 2 both directly and through pnpm. I added that probe to `app/package.json`, then restored the file and confirmed it byte-identical and clean in git. G2 can judge exit codes with `pnpm csvq` without bypassing pnpm.

I also probed ten edge cases the worker deliberately left alone, and every one is unhandled exactly as finding 4 claims — no quiet half-implementation, and now G2 has a measured starting line instead of a guess. Those measurements are in the NEXT block.

Proceeding to G2, the last goal.

BUS-VERDICT: PASS
BUS-NEXT-BEGIN
G1 is accepted, all nine rows. I re-ran every AC command and all three checks myself and got byte-for-byte what you reported, including the 106-byte round trip on basic.csv. Your AC-4 evidence was the right choice: the zero-row case with name=Ben, against the control that name=Ben alone matches, is what actually proves AND rather than merely illustrating it. Re-running every AC command after the biome reformat was also correct and is why I could trust the quoted output.

Ruling on your contract gap: CRLF inside a quoted field normalising to LF is accepted as a reading, not a change. It is the only reading consistent with the frozen "output uses LF" rule. Leave it in the Contract changes table as a reading note, and state it outright in the AS-BUILT rewrite so it stops being implicit.

Start G2, the final goal: rows AC-7 through AC-11 plus the five G2 closing rows in PROGRESS.md. After this there is no next goal.

Before you write code, here is the measured starting line. I probed these myself at the end of G1, so you can trust them as the current behaviour, and each one is a thing G2 must change:

- unknown --where column: silently 0 rows at exit 0
- unknown --select column: a header with empty cells at exit 0
- --sum name (non-numeric): prints NaN at exit 0
- --format xml: silently falls back to csv at exit 0
- --count --format json: prints 5 instead of refusing
- broken.csv: prints a mangled record at exit 0 instead of failing
- a missing file, an unknown option, and --select with no value: an uncaught Node stack trace at exit 1, not a named message at the contracted code

Work in this order.

1. Errors and exit codes first, since AC-7 through AC-9 all depend on the same plumbing. The contract is frozen and binding: exit 1 for a usage error (unknown option, missing value, unknown column, a forbidden combination) with a message naming the option or column; exit 2 for an input error (missing file, unterminated quote, a record with a different field count from the header, a non-numeric value under --sum) with the line number where it applies. Messages go to stderr, not stdout. Note that the field-count rule and the non-numeric-under---sum rule are in the frozen contract but not in any AC row — implement them anyway, because G2 rewrites SCOPE.md as AS-BUILT and a contract clause with no implementation is a difference you would have to mark. broken.csv gives you the unterminated quote; you will need to construct a ragged-record input yourself, in the temp directory.

2. For AC-9, broken.csv's unterminated quote opens on line 3 — I confirmed that reading of the raw file at G0, so line 3 is the number your error message must produce. A message naming a different line is a FAIL of that row even if the exit code is right.

3. Then --format json properly (AC-10): an array of objects keyed by header, and --count --format json refused as a usage error at exit 1. While you are there, --format with an unrecognised value must be a usage error too rather than falling back to csv. Also enforce the rest of the frozen combination rule: --count and --sum cannot be combined with each other. And --help, which is in the frozen interface table but has no AC row: print the usage and exit 0.

4. Then AC-11, the performance check. Generate the 10,000-record file in the OS temp directory via os.tmpdir() — never under app/. Run --where and --sum over it, time three runs, and report all three numbers plus the median; the row passes if the median is below 1 s. Do not report a best-of. Delete the file afterwards and show that you did.

5. Then close the run. Rewrite SCOPE.md as AS-BUILT: diff it against the frozen text with `git show HEAD:examples/toy-run/specs/csvq/SCOPE.md` rather than working from memory, and mark every difference from the frozen contract, each with a reason, in the Contract changes table. Write app/README.md showing usage with real output — the acceptance check on it is that its examples match a real run, so paste each command from the README into a shell and confirm the output matches before you call that row PASS. Then the change list with one proposed commit message per goal, G0 through G2. Do not commit anything; writing the messages is the deliverable.

6. Judge every AC row by running the CLI and quoting what it printed, including the exit code — `echo $?` or equivalent, since the code is half of what AC-7 through AC-9 assert. Exit codes survive pnpm intact: I verified that a script exiting 2 returns 2 through `pnpm run`, so `pnpm csvq …` is fine for these rows and you do not need to bypass pnpm. Remember that pnpm prints its own `$ node src/cli.ts …` echo line to stderr; do not mistake it for your program's output when quoting stderr.

7. Before reporting complete: all three checks green and quoted; the change set confined to app/ and specs/csvq/; pnpm-workspace.yaml and all three fixtures untouched; the generated performance file gone; no empty verdict anywhere in the ledger, including the five closing rows; and the Handover section filled in, each item as fact, impact and the decision needed. Add tests for the new error paths — the error behaviour is the bulk of G2 and it should not rest on manual runs alone.

Budget: about 30 turns. If a row fights you, record it FAIL with the input and the actual output and move on rather than stalling — an honest FAIL on one row is worth more to me than a stalled goal, and this is the last goal, so unfinished rows have nowhere to go. If something outside your reach blocks you, report BLOCKED with the reason and what you tried.
BUS-NEXT-END

## G2 — review #3, full reply (2026-09-29 18:03:56)

**Review 3 — G2 — verdict DONE.** The run is closed: 24 rows across three goals, all PASS.

I re-ran the acceptance rows rather than reading them. AC-7: `--nope` → exit 1, `csvq: unknown option "--nope"` on stderr, stdout empty. AC-8: all three options reject an unknown column at exit 1 and name it. AC-9: a missing file → exit 2, and `broken.csv` → exit 2 with `unterminated quote on line 3` — the line I confirmed off the raw file at G0, before any code existed to find it. AC-10: `--format json` prints an array of objects and honours `--select`; `--count --format json` → exit 1.

I gave particular attention to the clauses that are in the frozen contract but have no AC row, since those are where a "finished" tool usually isn't. Every one is implemented: `--sum name` → exit 2, `"Aiko" on line 2 is not a number`; `--count --sum` → 1; `--format xml` → 1 rather than a silent fallback; `--select` with no value → 1; no file → 1; `--help` → 0. I built my own ragged-record file and got exit 2 with `record on line 3 has 3 fields, but the header has 2`. I also re-ran the entire G1 surface as a regression check — the error plumbing threaded line numbers through the parser, which is exactly the kind of change that quietly breaks working output, and nothing moved.

I checked the nine AS-BUILT differences against the tool rather than against their own table. D2, D3, D5, D6 and D9 all behave as documented, including the subtle one: `nope.csv --bogus` exits 1, not 2, because the command line is judged before the file is opened. The rewrite is honest — nine clarifications, each with a reason, and I agree with the worker's assessment that none reverses a frozen decision. Marking D2 and D6 as defensibly reversible in the handover rather than presenting them as inevitable is the right call.

On the README I did my own extraction rather than trust the worker's verifier, and got it wrong twice before getting it right — first by collecting stdout and stderr separately, which destroys the interleaving, then by writing a redirect that bound to the trailing `echo` instead of the command. Once the whole line's output was captured as a terminal would see it: 14 blocks, 14 match, 0 mismatch, error examples and exit codes included. The runbook's own post-G2 check is that the README matches a real run, and it does.

**The AC-11 ruling, which the worker correctly left to me.** It reported both numbers instead of the flattering one and invited me to overturn it, so it earned a real answer rather than a nod. I generated my own 10,000-record file and timed it: bare `node` 135/149/167 ms, median 149; through `pnpm` 1312/1274/1284, median 1284. Close enough to the worker's figures to confirm them. The decisive measurement is the control: `pnpm` on the **5-record** fixture costs 1290 ms — indistinguishable from the 10,000-record run. The launcher toll is constant and has nothing to do with the data. So under the invocation reading, no implementation could ever pass this row on this machine; `node -e ''` alone costs 107 ms and pnpm's floor is 1.29 s. A criterion that no possible implementation can satisfy is not measuring the implementation. The row measures whether csvq handles 10,000 records quickly, and it does so in about 40 ms of work. **PASS upheld.** The worker also checked correctness before timing — its `995117` matched its generator's independent sum, and my own generator's `159903` matched mine — so the number isn't the speed of doing the wrong thing.

One thing I nearly got wrong: the handover says two `.gitkeep` files remain beside real files, and my `ls -R` showed no such thing. They are hidden files; `ls -a` and `git ls-files` both confirm `app/src/.gitkeep` and `app/test/.gitkeep` are there and tracked. The worker was right and my first check was too shallow.

Final state verified in the tree: `Tests  39 passed (39)` across two files, `Checked 5 files in 11ms. No fixes applied.`, typecheck exit 0. The new `cli.test.ts` drives the CLI as a real process via `spawnSync` and asserts on exit codes, which is the only way these contract rows can honestly be tested. Its scratch files go to `mkdtempSync` under `tmpdir()` with an `afterAll` cleanup. `pnpm-workspace.yaml` and all three fixtures are untouched, nothing over 100 KB sits under `app/`, `ls -d /tmp/csvq-*` finds nothing, and every change is inside `app/` or `specs/csvq/`. Nothing is committed, which is correct — the three proposed messages are the deliverable.

Across the run this worker never once needed a REJECT. The habits that earned that: quoting output it actually ran, choosing AC evidence that discriminates rather than illustrates, volunteering its own failures (the lint reformat, and re-running every AC afterwards so the quotes still matched the file on disk), stopping cleanly at each goal boundary, and bringing me a genuine judgment call with both numbers instead of the one that suited it.

What remains is the human's, per the runbook: read BUS-REVIEWS.md, commit the work, record the run in `examples/toy-run/README.md`, then `rm specs/csvq/.bus-armed specs/csvq/.gate-armed`. Two handover items are about the kit rather than csvq and are worth fixing in the pack itself — `goal-brief.md`'s environment block describes a different machine, and a performance AC should name the invocation it is measured through, or the next run will hit the same 1.27 s launcher wall I just ruled on.

BUS-VERDICT: DONE
BUS-NEXT-BEGIN
csvq is complete: 24 of 24 rows PASS across G0-G2, no REJECT in the run, contract rewritten AS-BUILT with nine marked clarifications, README verified against real runs, and nothing left to commit but the work itself.
BUS-NEXT-END
