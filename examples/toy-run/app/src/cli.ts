#!/usr/bin/env node
// csvq — a small CSV query CLI. The behaviour, the exit codes and the CSV dialect are fixed by
// specs/csvq/SCOPE.md: 0 success, 1 usage error (naming the option or column), 2 input error
// (naming the line it applies to). Every message goes to stderr; only results go to stdout.
import { readFileSync } from "node:fs";
import { CsvError, type CsvRecord, formatCsv, parseCsv, toRows } from "./csv.ts";

// Exit 1: the command line is wrong. Exit 2: the file is wrong.
class UsageError extends Error {}
class InputError extends Error {}

const USAGE = `csvq — print selected columns, filtered rows, a count or a sum from a CSV file

usage: csvq <file> [options]

options:
  --select <col>[,<col>...]  print only these columns, in this order
  --where <col>=<value>      keep rows whose column equals the value exactly;
                             may be repeated, and every one must match
  --count                    print only the number of matching rows
  --sum <col>                print only the sum of a numeric column over those rows
  --format csv|json          how rows are printed (default: csv)
  --help                     print this usage and exit 0

--count and --sum cannot be combined with each other or with --format json.

exit codes:
  0  success
  1  usage error: unknown option, missing value, unknown column, a forbidden combination
  2  input error: missing file, unterminated quote, a record with a different number of
     fields from the header, a non-numeric value under --sum
`;

interface Clause {
  column: string;
  value: string;
}

interface Options {
  help: boolean;
  file: string;
  select: string[] | null;
  where: Clause[];
  count: boolean;
  sum: string | null;
  format: "csv" | "json";
}

// Reads the value that belongs to an option, so "--select" with nothing after it is a usage
// error naming the option rather than an undefined that surfaces much later.
function valueFor(argv: string[], i: number, option: string): string {
  const value = argv[i + 1];
  if (value === undefined) throw new UsageError(`the option "${option}" needs a value`);
  return value;
}

function parseArgs(argv: string[]): Options {
  const options: Options = {
    help: false,
    file: "",
    select: null,
    where: [],
    count: false,
    sum: null,
    format: "csv",
  };
  let sawFile = false;
  let i = 0;

  while (i < argv.length) {
    const arg = argv[i];
    if (arg === "--help") {
      options.help = true;
      i += 1;
    } else if (arg === "--select") {
      options.select = valueFor(argv, i, arg).split(",");
      i += 2;
    } else if (arg === "--where") {
      // Only the first "=" separates the column from the value, so a value may contain one.
      const raw = valueFor(argv, i, arg);
      const at = raw.indexOf("=");
      if (at < 1) throw new UsageError(`--where needs <column>=<value>, got "${raw}"`);
      options.where.push({ column: raw.slice(0, at), value: raw.slice(at + 1) });
      i += 2;
    } else if (arg === "--count") {
      options.count = true;
      i += 1;
    } else if (arg === "--sum") {
      options.sum = valueFor(argv, i, arg);
      i += 2;
    } else if (arg === "--format") {
      const raw = valueFor(argv, i, arg);
      if (raw !== "csv" && raw !== "json") {
        throw new UsageError(`unknown value "${raw}" for --format (use "csv" or "json")`);
      }
      options.format = raw;
      i += 2;
    } else if (arg.startsWith("-") && arg !== "-") {
      throw new UsageError(`unknown option "${arg}"`);
    } else if (sawFile) {
      throw new UsageError(`unexpected extra argument "${arg}" (csvq takes one file)`);
    } else {
      options.file = arg;
      sawFile = true;
      i += 1;
    }
  }

  if (options.help) return options;

  // The frozen combination rule, and the one case where a file is simply absent from the command.
  if (options.count && options.sum !== null) {
    throw new UsageError("--count and --sum cannot be combined");
  }
  if (options.format === "json" && options.count) {
    throw new UsageError("--count cannot be combined with --format json");
  }
  if (options.format === "json" && options.sum !== null) {
    throw new UsageError("--sum cannot be combined with --format json");
  }
  if (!sawFile) throw new UsageError("no input file given (usage: csvq <file> [options])");
  return options;
}

function read(file: string): string {
  try {
    return readFileSync(file, "utf8");
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ENOENT") throw new InputError(`cannot read "${file}": no such file`);
    if (code === "EISDIR") throw new InputError(`cannot read "${file}": it is a directory`);
    throw new InputError(`cannot read "${file}": ${code ?? String(error)}`);
  }
}

function columnIndex(header: string[], column: string, option: string): number {
  const at = header.indexOf(column);
  if (at < 0) throw new UsageError(`unknown column "${column}" in ${option}`);
  return at;
}

function sum(records: CsvRecord[], at: number, column: string): number {
  let total = 0;
  for (const record of records) {
    const raw = record.fields[at] ?? "";
    const value = raw.trim() === "" ? Number.NaN : Number(raw);
    if (!Number.isFinite(value)) {
      throw new InputError(
        `cannot sum "${column}": "${raw}" on line ${record.line} is not a number`,
      );
    }
    total += value;
  }
  return total;
}

function run(argv: string[]): void {
  const options = parseArgs(argv);
  if (options.help) {
    process.stdout.write(USAGE);
    return;
  }

  const text = read(options.file);
  let table: ReturnType<typeof parseCsv>;
  try {
    table = parseCsv(text);
  } catch (error) {
    if (error instanceof CsvError) {
      throw new InputError(`cannot read "${options.file}": ${error.message}`);
    }
    throw error;
  }

  // Every --where must match: each clause narrows what the previous one left.
  let records = table.records;
  for (const clause of options.where) {
    const at = columnIndex(table.header, clause.column, "--where");
    records = records.filter((record) => record.fields[at] === clause.value);
  }

  if (options.count) {
    process.stdout.write(`${records.length}\n`);
    return;
  }

  if (options.sum !== null) {
    const at = columnIndex(table.header, options.sum, "--sum");
    process.stdout.write(`${sum(records, at, options.sum)}\n`);
    return;
  }

  const columns = options.select ?? table.header;
  const indexes = columns.map((column) => columnIndex(table.header, column, "--select"));
  const picked = records.map((record) => indexes.map((at) => record.fields[at] ?? ""));

  if (options.format === "json") {
    process.stdout.write(`${JSON.stringify(toRows(columns, picked), null, 2)}\n`);
    return;
  }
  process.stdout.write(`${formatCsv(columns, picked)}\n`);
}

function main(argv: string[]): number {
  try {
    run(argv);
    return 0;
  } catch (error) {
    if (error instanceof UsageError) {
      process.stderr.write(`csvq: ${error.message}\n`);
      return 1;
    }
    if (error instanceof InputError) {
      process.stderr.write(`csvq: ${error.message}\n`);
      return 2;
    }
    throw error;
  }
}

process.exitCode = main(process.argv.slice(2));
