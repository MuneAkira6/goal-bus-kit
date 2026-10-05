You are the worker for the csvq toy run. First read specs/csvq/goal-brief.md completely, then
specs/csvq/SCOPE.md and specs/csvq/PROGRESS.md.

This goal is G0: environment check and contract freeze. Work inside app/ and specs/csvq/ only.

1. Record `node --version` and `pnpm --version` in the Environment table of PROGRESS.md, with the output.
2. In app/, run `pnpm install` without changing pnpm-workspace.yaml. Record the result and how long it took.
3. In app/, add one placeholder test so the runner has something to run, then run `pnpm test`,
   `pnpm lint` and `pnpm typecheck` and quote their last lines.
4. Measure the three given fixtures (records and fields per record) without editing them.
5. Mark SCOPE.md as FROZEN with today's date, changing nothing else in it.

Judge every G0 row in PROGRESS.md with the output you quote. End every turn on a progress line such as
`PROGRESS: G0 ac_done=2/5 pass=2 fail=0 blocked=0 deferred=0`, and when every G0 row has a verdict,
end with `PROGRESS: G0 COMPLETE`.
