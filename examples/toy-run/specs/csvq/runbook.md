# Runbook — csvq toy run

## 0. Before arming

- [ ] `git status` is clean in the kit repository.
- [ ] Nothing else runs in `examples/toy-run/`.
- [ ] The usage budget for the run is available.

## 1. Launch (one command)

```bash
bash examples/toy-run/launch.sh
```

It installs the kit's hooks into `examples/toy-run/` (the first time; both selftests run there), seeds the
bus, arms both latches and starts the worker with `specs/csvq/g0-instructions.md`. The worker runs in the
foreground; its output goes to `specs/csvq/.worker-log`. Watch from a second terminal:

```bash
cd examples/toy-run && bash .claude/hooks/bin/watch.sh 60
```

## 2. The goals

| Goal | The bus adapts this into instructions | Check yourself after the PASS |
|---|---|---|
| G0 | versions, install, the skeleton's test/lint/typecheck, fixture measurements, SCOPE.md frozen | the install did not touch pnpm-workspace.yaml |
| G1 | a small RFC 4180 reader with unit tests first (quoted commas, doubled quotes, embedded line breaks, empty quoted field), then `--select`, `--where`, `--count`, `--sum`, each judged by running the CLI | `pnpm test` is green; the Osaka sum is 1650 |
| G2 | argument and input errors with exit codes 1 and 2 and line numbers, `--format json`, a 10,000-record performance check in the OS temp directory, SCOPE.md as AS-BUILT, app/README.md, a change list | the README output matches a real run |

## 3. When the relay stops

| Situation | What to do |
|---|---|
| DONE | read BUS-LOG.md and BUS-REVIEWS.md, commit, then remove both latches |
| ESCALATE | answer with `bash .claude/hooks/goal-bus.sh --notify "<ruling>"`, then `bash .claude/hooks/bin/start-worker.sh --resume <worker-id> --file specs/csvq/.bus-next` |
| Usage limit | wait for the reset, then resume the worker with "continue"; never retry in a loop |
| Anything else | `bash .claude/hooks/goal-bus.sh --status`, then decide |

## 4. After the run

- Rubber-stamp audit: read BUS-REVIEWS.md against the checklist in the kit's runbook template.
- Record in `examples/toy-run/README.md`: date, model, goals, reviews, REJECTs, bus-side `cost_usd` (as
  reported by the CLI, an API-equivalent figure), wall-clock time, and anything a human did.
- Disarm: `rm specs/csvq/.bus-armed specs/csvq/.gate-armed`
