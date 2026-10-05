
## Bus seeded (2026-09-29 17:34:17)

- session: `812d8b5e-cf89-433b-93c3-aaa2c422d497`
- model: opus[1m]

## G0 — review #1 (2026-09-29 17:43:53)

**Verdict: PASS** (bus context: 44904 tokens)

G0 is accepted. All five rows passed; I re-ran your three checks, re-derived every fixture measurement from the raw files, and confirmed pnpm-workspace.yaml and the fixtures are untouched. Your reading of broken.csv (unterminated quote opening on line 3) is correct and G2 will be judged against it. Your incidental finding 1 is upheld: goal-brief.md's "facts already verified" block was written on a different machine and is wrong about this one. Trust what you observe over what the brief predicts, and keep filing such gaps as findings rather than editing the brief.

Start G1: the RFC 4180 reader and the core options, rows AC-1 through AC-6 plus the three G1 checks in PROGRESS.md.

Work in this order.

1. Build the reader first, with unit tests before the CLI. Put the parser in app/src/ as its own module and give it Vitest tests in app/test/ that cover, as separate cases: a field containing a comma inside quotes; a doubled quote inside a quoted field resolving to one quote character; a quoted field containing a line break; an empty quoted field; and CRLF line endings accepted alongside LF. The fixtures give you the first four for free — quoted.csv record 1 is "Suzuki, Taro" with note `says "hello"`, record 2's note spans lines 3-4, record 3 is `3,"",plain`. CRLF is in the contract but not in any fixture, so build that input inline in the test. Replace app/test/placeholder.test.ts as part of this; it exists only so G0 had something to run.

2. Then the CLI at app/src/cli.ts, wiring --select, --where, --count and --sum. Repeated --where is an AND: every one must match.

3. Judge each AC row by running the CLI and quoting what it printed. Unit tests passing is not evidence for an AC row — app/src/ was empty until now, so I will read these rows as claims about the tool's actual output. Run it as `pnpm csvq <args>` from app/ (the script is `node src/cli.ts`). Expected results I derived myself from basic.csv, so you can check against them: the file has 5 data records; --where city=Osaka keeps exactly 2 (Aiko 1200 and Chika 450); --sum amount with that filter is 1650; --sum amount with no filter is 4750. For AC-4's second half use a pair like --where city=Osaka --where name=Aiko, which must keep 1 record, and show a non-matching combination too so the AND is visibly doing work. For AC-2 use --format json on quoted.csv and quote the output, since that is how the row asks to see the parse; implement only as much of json output as AC-2 needs to display rows. Do not build out the rest of --format, the error paths, exit codes or the performance check — those are G2 rows and starting them now is scope creep I will reject.

4. Environment notes that will save you time. Node here runs .ts directly by stripping types, so there is no build step and you must not add one. tsconfig.json sets verbatimModuleSyntax and allowImportingTsExtensions, so write intra-project imports with the explicit .ts suffix and use `import type` for type-only imports, or typecheck will fail. Biome's lint preset is "recommended" over src/** and test/**. The install runs under pnpm 11.0.9 via corepack regardless of the 11.22.0 on PATH. Proxy variables are set in this environment: do not unset, change or print them.

5. Before you report complete: `pnpm test`, `pnpm lint` and `pnpm typecheck` all green, quoted in the G1 checks table; `git status --short` showing the change set confined to app/src, app/test and specs/csvq; pnpm-workspace.yaml and app/fixtures/ untouched; no scratch files left outside the OS temp directory; and no empty verdict in the G1 section. Every row gets PASS, FAIL, BLOCKED or DEFERRED with the command and its real output beside it.

Budget: about 25 turns. If the parser fights you on a specific quoting case, record that row FAIL with the input and the wrong output and keep going rather than stalling on it. If something outside your reach blocks you — a red-line file you would have to change, or a contract question SCOPE.md does not answer — stop and report BLOCKED with the reason and what you tried; do not work around it.

## G1 — review #2 (2026-09-29 17:52:01)

**Verdict: PASS** (bus context: 69125 tokens)

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

## G2 — review #3 (2026-09-29 18:03:56)

**Verdict: DONE** (bus context: 99138 tokens)

csvq is complete: 24 of 24 rows PASS across G0-G2, no REJECT in the run, contract rewritten AS-BUILT with nine marked clarifications, README verified against real runs, and nothing left to commit but the work itself.
