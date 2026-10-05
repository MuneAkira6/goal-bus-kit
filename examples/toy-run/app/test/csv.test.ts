import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { CsvError, formatCsv, parseCsv, toRows } from "../src/csv.ts";

const quoted = parseCsv(readFileSync(new URL("../fixtures/quoted.csv", import.meta.url), "utf8"));
const basic = parseCsv(readFileSync(new URL("../fixtures/basic.csv", import.meta.url), "utf8"));

const fieldsOf = (table: typeof basic) => table.records.map((record) => record.fields);

describe("parseCsv", () => {
  it("reads the header and every data record", () => {
    expect(basic.header).toEqual(["id", "name", "city", "amount"]);
    expect(basic.records).toHaveLength(5);
    expect(basic.records[0].fields).toEqual(["1", "Aiko", "Osaka", "1200"]);
    expect(basic.records[4].fields).toEqual(["5", "Emi", "Tokyo", "300"]);
  });

  it("keeps a comma that is inside a quoted field", () => {
    // quoted.csv record 1: 1,"Suzuki, Taro",...  — the comma must not split the field.
    expect(quoted.records[0].fields[1]).toBe("Suzuki, Taro");
    expect(quoted.records[0].fields).toHaveLength(3);
  });

  it("resolves a doubled quote inside a quoted field to one quote character", () => {
    // quoted.csv record 1 note: "says ""hello"""
    expect(quoted.records[0].fields[2]).toBe('says "hello"');
  });

  it("keeps a line break that is inside a quoted field", () => {
    // quoted.csv record 2 note spans lines 3-4 of the file but is one field.
    expect(quoted.records[1].fields[2]).toBe("two\nlines");
    expect(quoted.records).toHaveLength(3);
  });

  it("reads an empty quoted field as an empty string", () => {
    // quoted.csv record 3: 3,"",plain
    expect(quoted.records[2].fields).toEqual(["3", "", "plain"]);
  });

  it("accepts CRLF line endings alongside LF", () => {
    // No fixture uses CRLF, so the input is built here. The CRLF file and the LF file must parse
    // identically, including a CRLF line break inside a quoted field, which is kept as LF.
    const lf = 'id,note\n1,"two\nlines"\n2,plain\n';
    const crlf = 'id,note\r\n1,"two\r\nlines"\r\n2,plain\r\n';
    expect(parseCsv(crlf)).toEqual(parseCsv(lf));
    expect(parseCsv(crlf).header).toEqual(["id", "note"]);
    expect(fieldsOf(parseCsv(crlf))).toEqual([
      ["1", "two\nlines"],
      ["2", "plain"],
    ]);
  });

  it("reads a last record that has no trailing line break", () => {
    expect(fieldsOf(parseCsv("id,name\n1,Aiko"))).toEqual([["1", "Aiko"]]);
  });

  it("numbers each record by the line it starts on, counting a quoted line break", () => {
    // quoted.csv record 2 starts on line 3; because its note spans to line 4, record 3 is line 5.
    expect(quoted.records.map((record) => record.line)).toEqual([2, 3, 5]);
  });
});

describe("parseCsv input errors", () => {
  it("rejects an unterminated quote, naming the line the quote opened on", () => {
    const text = readFileSync(new URL("../fixtures/broken.csv", import.meta.url), "utf8");
    expect(() => parseCsv(text)).toThrow(CsvError);
    try {
      parseCsv(text);
      expect.unreachable("broken.csv must not parse");
    } catch (error) {
      expect(error).toBeInstanceOf(CsvError);
      expect((error as CsvError).line).toBe(3);
      expect((error as CsvError).message).toBe("unterminated quote on line 3");
    }
  });

  it("rejects a record whose field count differs from the header, naming its line", () => {
    try {
      parseCsv("id,name\n1,Aiko\n2,Ben,extra\n");
      expect.unreachable("a ragged record must not parse");
    } catch (error) {
      expect(error).toBeInstanceOf(CsvError);
      expect((error as CsvError).line).toBe(3);
      expect((error as CsvError).message).toBe(
        "record on line 3 has 3 fields, but the header has 2",
      );
    }
  });

  it("rejects a record with too few fields as well", () => {
    try {
      parseCsv("id,name\n1\n");
      expect.unreachable("a short record must not parse");
    } catch (error) {
      expect((error as CsvError).message).toBe(
        "record on line 2 has 1 fields, but the header has 2",
      );
    }
  });
});

describe("toRows", () => {
  it("keys each record by the header", () => {
    expect(toRows(quoted.header, fieldsOf(quoted))[0]).toEqual({
      id: "1",
      name: "Suzuki, Taro",
      note: 'says "hello"',
    });
  });
});

describe("formatCsv", () => {
  it("quotes a field only when it holds a comma, a quote or a line break", () => {
    const out = formatCsv(
      ["a", "b", "c", "d"],
      [["plain", "has,comma", 'has"quote', "has\nbreak"]],
    );
    expect(out).toBe('a,b,c,d\nplain,"has,comma","has""quote","has\nbreak"');
  });

  it("round-trips the quoted fixture", () => {
    const written = `${formatCsv(quoted.header, fieldsOf(quoted))}\n`;
    expect(parseCsv(written).header).toEqual(quoted.header);
    expect(fieldsOf(parseCsv(written))).toEqual(fieldsOf(quoted));
  });
});
