// The RFC 4180 dialect SCOPE.md fixes: comma separator, fields optionally enclosed in double
// quotes, `""` inside a quoted field meaning one quote, quoted fields allowed to contain commas
// and line breaks, the first record being the header, LF and CRLF accepted on input, LF on output.

export type Row = Record<string, string>;

export interface CsvRecord {
  fields: string[];
  // 1-based line of the file where this record starts. Carried so an input error can name the
  // line "where it applies", which the contract requires of every exit-2 message.
  line: number;
}

export interface Table {
  header: string[];
  records: CsvRecord[];
}

// An input error in the file itself: exit 2 in the CLI. The message already names the line, and
// `line` is kept separately so a test can assert on it without matching prose.
export class CsvError extends Error {
  readonly line: number;

  constructor(message: string, line: number) {
    super(message);
    this.name = "CsvError";
    this.line = line;
  }
}

// A line break inside a quoted field is kept as LF whether it arrived as LF or CRLF, so that a
// value read from a CRLF file and the same value read from an LF file compare equal, and so that
// writing it back out obeys the contract's "output uses LF".
function scan(text: string): CsvRecord[] {
  const records: CsvRecord[] = [];
  let fields: string[] = [];
  let field = "";
  let inQuotes = false;
  let line = 1;
  let recordLine = 1;
  let quoteLine = 0;
  let i = 0;

  while (i < text.length) {
    const c = text[i];

    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 2;
          continue;
        }
        inQuotes = false;
        i += 1;
        continue;
      }
      if (c === "\n" || (c === "\r" && text[i + 1] === "\n")) {
        field += "\n";
        line += 1;
        i += c === "\r" ? 2 : 1;
        continue;
      }
      field += c;
      i += 1;
      continue;
    }

    if (c === '"') {
      inQuotes = true;
      quoteLine = line;
      i += 1;
      continue;
    }
    if (c === ",") {
      fields.push(field);
      field = "";
      i += 1;
      continue;
    }
    if (c === "\n" || (c === "\r" && text[i + 1] === "\n")) {
      fields.push(field);
      records.push({ fields, line: recordLine });
      fields = [];
      field = "";
      line += 1;
      recordLine = line;
      i += c === "\r" ? 2 : 1;
      continue;
    }
    field += c;
    i += 1;
  }

  // A quote still open at end of file is the contract's "unterminated quote": the line that
  // matters is the one the quote opened on, not the end of the file.
  if (inQuotes) throw new CsvError(`unterminated quote on line ${quoteLine}`, quoteLine);

  // A trailing line break ends the last record; without one, whatever is buffered is still a record.
  if (field !== "" || fields.length > 0) {
    fields.push(field);
    records.push({ fields, line: recordLine });
  }
  return records;
}

export function parseCsv(text: string): Table {
  const records = scan(text);
  if (records.length === 0) return { header: [], records: [] };

  const header = records[0].fields;
  const rest = records.slice(1);
  for (const record of rest) {
    if (record.fields.length !== header.length) {
      throw new CsvError(
        `record on line ${record.line} has ${record.fields.length} fields, but the header has ${header.length}`,
        record.line,
      );
    }
  }
  return { header, records: rest };
}

export function toRows(header: string[], records: string[][]): Row[] {
  const rows: Row[] = [];
  for (const record of records) {
    const row: Row = {};
    for (let i = 0; i < header.length; i += 1) {
      row[header[i]] = record[i] ?? "";
    }
    rows.push(row);
  }
  return rows;
}

export function formatField(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n") || value.includes("\r")) {
    return `"${value.replaceAll('"', '""')}"`;
  }
  return value;
}

export function formatCsv(header: string[], records: string[][]): string {
  const lines: string[] = [];
  for (const record of [header, ...records]) {
    lines.push(record.map((field) => formatField(field)).join(","));
  }
  return lines.join("\n");
}
