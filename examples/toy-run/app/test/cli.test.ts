import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterAll, describe, expect, it } from "vitest";

const cli = fileURLToPath(new URL("../src/cli.ts", import.meta.url));
const app = fileURLToPath(new URL("..", import.meta.url));

// The exit code is half of what the contract asserts, so the CLI is driven as a real process
// rather than by importing it.
function csvq(...args: string[]) {
  const result = spawnSync(process.execPath, [cli, ...args], { cwd: app, encoding: "utf8" });
  return { code: result.status, out: result.stdout, err: result.stderr };
}

// Scratch inputs the fixtures cannot provide live in the OS temp directory, never under app/.
const scratch = mkdtempSync(join(tmpdir(), "csvq-test-"));
afterAll(() => rmSync(scratch, { recursive: true, force: true }));

function scratchFile(name: string, content: string): string {
  const path = join(scratch, name);
  writeFileSync(path, content);
  return path;
}

describe("exit 0 — success", () => {
  it("prints the file back", () => {
    const { code, out } = csvq("fixtures/basic.csv");
    expect(code).toBe(0);
    expect(out).toBe(
      "id,name,city,amount\n1,Aiko,Osaka,1200\n2,Ben,Tokyo,800\n3,Chika,Osaka,450\n4,Dan,Nagoya,2000\n5,Emi,Tokyo,300\n",
    );
  });

  it("prints the usage and exits 0 for --help", () => {
    const { code, out, err } = csvq("--help");
    expect(code).toBe(0);
    expect(out).toContain("usage: csvq <file> [options]");
    expect(err).toBe("");
  });

  it("prints an array of objects for --format json", () => {
    const { code, out } = csvq("fixtures/quoted.csv", "--format", "json");
    expect(code).toBe(0);
    expect(JSON.parse(out)).toEqual([
      { id: "1", name: "Suzuki, Taro", note: 'says "hello"' },
      { id: "2", name: "Kato", note: "two\nlines" },
      { id: "3", name: "", note: "plain" },
    ]);
  });
});

describe("exit 1 — usage errors", () => {
  it("names an unknown option", () => {
    const { code, out, err } = csvq("fixtures/basic.csv", "--nope");
    expect(code).toBe(1);
    expect(err).toBe('csvq: unknown option "--nope"\n');
    expect(out).toBe("");
  });

  it("names an option that is missing its value", () => {
    const { code, err } = csvq("fixtures/basic.csv", "--select");
    expect(code).toBe(1);
    expect(err).toBe('csvq: the option "--select" needs a value\n');
  });

  it.each([
    ["--select", "nope", 'csvq: unknown column "nope" in --select\n'],
    ["--sum", "nope", 'csvq: unknown column "nope" in --sum\n'],
  ])("names an unknown column in %s", (option, column, message) => {
    const { code, err } = csvq("fixtures/basic.csv", option, column);
    expect(code).toBe(1);
    expect(err).toBe(message);
  });

  it("names an unknown column in --where", () => {
    const { code, err } = csvq("fixtures/basic.csv", "--where", "nope=x");
    expect(code).toBe(1);
    expect(err).toBe('csvq: unknown column "nope" in --where\n');
  });

  it("rejects an unrecognised --format value instead of falling back to csv", () => {
    const { code, out, err } = csvq("fixtures/basic.csv", "--format", "xml");
    expect(code).toBe(1);
    expect(err).toBe('csvq: unknown value "xml" for --format (use "csv" or "json")\n');
    expect(out).toBe("");
  });

  it.each([
    [["--count", "--sum", "amount"], "csvq: --count and --sum cannot be combined\n"],
    [["--count", "--format", "json"], "csvq: --count cannot be combined with --format json\n"],
    [
      ["--sum", "amount", "--format", "json"],
      "csvq: --sum cannot be combined with --format json\n",
    ],
  ])("refuses the forbidden combination %s", (args, message) => {
    const { code, out, err } = csvq("fixtures/basic.csv", ...args);
    expect(code).toBe(1);
    expect(err).toBe(message);
    expect(out).toBe("");
  });

  it("rejects --where without an =", () => {
    const { code, err } = csvq("fixtures/basic.csv", "--where", "city");
    expect(code).toBe(1);
    expect(err).toBe('csvq: --where needs <column>=<value>, got "city"\n');
  });

  it("rejects a command with no file at all", () => {
    const { code, err } = csvq("--count");
    expect(code).toBe(1);
    expect(err).toContain("no input file given");
  });
});

describe("exit 2 — input errors", () => {
  it("reports a missing file", () => {
    const { code, out, err } = csvq("fixtures/nope.csv");
    expect(code).toBe(2);
    expect(err).toBe('csvq: cannot read "fixtures/nope.csv": no such file\n');
    expect(out).toBe("");
  });

  it("reports the unterminated quote in broken.csv with its line number", () => {
    const { code, out, err } = csvq("fixtures/broken.csv");
    expect(code).toBe(2);
    expect(err).toBe('csvq: cannot read "fixtures/broken.csv": unterminated quote on line 3\n');
    expect(out).toBe("");
  });

  it("reports a record whose field count differs from the header", () => {
    const path = scratchFile("ragged.csv", "id,name\n1,Aiko\n2,Ben,extra\n");
    const { code, err } = csvq(path);
    expect(code).toBe(2);
    expect(err).toBe(
      `csvq: cannot read "${path}": record on line 3 has 3 fields, but the header has 2\n`,
    );
  });

  it("reports a non-numeric value under --sum with its line number", () => {
    const { code, out, err } = csvq("fixtures/basic.csv", "--sum", "name");
    expect(code).toBe(2);
    expect(err).toBe('csvq: cannot sum "name": "Aiko" on line 2 is not a number\n');
    expect(out).toBe("");
  });

  it("reports an empty value under --sum rather than counting it as zero", () => {
    const path = scratchFile("blank.csv", "id,amount\n1,10\n2,\n");
    const { code, err } = csvq(path, "--sum", "amount");
    expect(code).toBe(2);
    expect(err).toBe(`csvq: cannot sum "amount": "" on line 3 is not a number\n`);
  });

  it("only rejects a bad value the filter actually reaches", () => {
    // Row 2's amount is unusable, but --where excludes it, so the sum still succeeds.
    const path = scratchFile("mixed.csv", "id,city,amount\n1,Osaka,10\n2,Tokyo,oops\n");
    const { code, out } = csvq(path, "--sum", "amount", "--where", "city=Osaka");
    expect(code).toBe(0);
    expect(out).toBe("10\n");
  });
});

describe("the core options still behave", () => {
  it.each([
    [["--count"], "5\n"],
    [["--count", "--where", "city=Osaka"], "2\n"],
    [["--sum", "amount"], "4750\n"],
    [["--sum", "amount", "--where", "city=Osaka"], "1650\n"],
  ])("csvq fixtures/basic.csv %s", (args, expected) => {
    const { code, out } = csvq("fixtures/basic.csv", ...args);
    expect(code).toBe(0);
    expect(out).toBe(expected);
  });

  it("ANDs repeated --where", () => {
    expect(
      csvq("fixtures/basic.csv", "--count", "--where", "city=Osaka", "--where", "name=Aiko").out,
    ).toBe("1\n");
    expect(
      csvq("fixtures/basic.csv", "--count", "--where", "city=Osaka", "--where", "name=Ben").out,
    ).toBe("0\n");
    expect(csvq("fixtures/basic.csv", "--count", "--where", "name=Ben").out).toBe("1\n");
  });
});
