# csvq — scope and contract

**Contract status: AS-BUILT 2026-09-29** (frozen as written on 2026-09-29 in G0; rewritten here in G2
against the finished tool). Every difference from the frozen text is marked **[D1]**…**[D9]** and
explained under "Differences from the frozen contract" at the end; the reasons are also in the
Contract changes table of PROGRESS.md.

csvq is a small command-line tool that reads a CSV file and prints selected columns, filtered rows, a
row count or a column sum. It exists to give goal-bus-kit a real, small run — keep it small.

## Interface

```
csvq <file> [options]
```

| Option | Meaning |
|---|---|
| `--select <col>[,<col>…]` | print only these columns, in this order |
| `--where <col>=<value>` | keep rows whose column equals the value exactly; may be repeated, and every one must match |
| `--count` | print only the number of matching rows |
| `--sum <col>` | print only the sum of a numeric column over the matching rows |
| `--format csv\|json` | how rows are printed (default `csv`); `json` is an array of objects keyed by header |
| `--help` | print the usage and exit 0 |

`--count` and `--sum` cannot be combined with each other or with `--format json`.

Exactly one file is given, and it is required **[D2]**. `--help` is answered before anything else, so
`csvq --help` alone is valid and prints the usage **[D3]**. Options may appear before or after the file.
In `--where <col>=<value>` only the first `=` separates the two, so a value may itself contain one.

## Exit codes

| Code | When | Message |
|---|---|---|
| 0 | success | — |
| 1 | usage error: unknown option, missing value, unknown column, a forbidden combination, an unrecognised `--format` value **[D4]**, no file or more than one file **[D2]**, a `--where` argument with no `=` **[D5]** | names the option or column |
| 2 | input error: missing file, unterminated quote, a record with a different number of fields from the header, a non-numeric value under `--sum` (an empty value counts as non-numeric **[D6]**) | includes the line number where it applies, except for a missing file, which has no line **[D7]** |

Results are written to stdout; every error message is written to stderr and is prefixed `csvq: ` **[D8]**.
Usage errors are detected before the file is opened, so a command that is both malformed and names a
missing file exits 1, not 2 **[D9]**. A value rejected under `--sum` is only one the filters actually
reach: `--where` is applied first.

## CSV dialect

RFC 4180: comma separator; fields may be enclosed in double quotes; `""` inside a quoted field is one
quote; quoted fields may contain commas and line breaks; the first record is the header; LF and CRLF
are accepted on input; output uses LF, and an output field is quoted when it contains a comma, a quote
or a line break.

A line break **inside** a quoted field is kept as LF whether it arrived as LF or as CRLF **[D1]**. A
record's reported line number is the line it starts on, so a record containing a quoted line break
advances the count by more than one.

## Out of scope

Type inference beyond `--sum`, other separators, streaming very large files, localisation.

## Files

- `app/src/csv.ts` the RFC 4180 reader and writer, `app/src/cli.ts` the command line.
- `app/test/csv.test.ts` parser and writer tests, `app/test/cli.test.ts` end-to-end tests that run the
  CLI as a process and assert on its exit code and stderr.
- `app/fixtures/basic.csv`, `quoted.csv`, `broken.csv` are given. Do not edit them.

## Differences from the frozen contract

Each one is a clarification of something the frozen text left open; none reverses a frozen decision.

| # | Difference | Reason |
|---|---|---|
| D1 | A CRLF inside a quoted field is stored as LF. | The frozen text says quoted fields may contain line breaks, and that output uses LF, but not which a CRLF inside a field becomes. LF is the only reading consistent with the frozen output rule, and it makes a CRLF file and the same LF file parse equal. Raised in G1 and ruled a reading, not a change. |
| D2 | No file, or a second file, is a usage error (exit 1). | The frozen exit-2 row says "missing file", which is the file not existing on disk. A command that names no file at all is malformed rather than pointing at a missing file, and `csvq <file>` is singular. |
| D3 | `--help` is answered before the combination rules and before the file requirement. | The frozen row says `--help` prints the usage and exits 0; that cannot hold if `--help` first had to satisfy the other rules. |
| D4 | `--format zzz` is a usage error (exit 1). | The frozen table gives `--format` exactly two values. Silently falling back to `csv` would let a typo change the output format unnoticed. |
| D5 | `--where city` (no `=`) is a usage error (exit 1). | The frozen grammar is `--where <col>=<value>`; an argument with no `=` supplies no value, which the frozen text already lists as a usage error. |
| D6 | An empty value under `--sum` is non-numeric (exit 2). | The frozen text says "a non-numeric value under `--sum`" without ruling on empty. An empty cell is absent data, not zero, and silently adding 0 would hide it. |
| D7 | A missing-file message carries no line number. | The frozen text asks for "the line number where it applies"; a file that does not exist has no line for it to apply to. Every other exit-2 message does carry one. |
| D8 | Errors go to stderr, prefixed `csvq: `; only results go to stdout. | The frozen table has a "Message" column but names no stream. Keeping stdout clean is what lets `csvq … > out.csv` stay valid when the command fails. |
| D9 | Usage errors are detected before the file is opened. | Two rules can apply at once; the frozen text does not say which wins. Checking the command line first means the exit code always describes the first thing that is wrong. |
