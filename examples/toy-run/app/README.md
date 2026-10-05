# csvq

A small CSV query CLI: print selected columns, filtered rows, a row count or a column sum.
The contract it implements is [specs/csvq/SCOPE.md](../specs/csvq/SCOPE.md).

Node 24 or later runs the TypeScript directly, so there is no build step. Run it either way:

```
pnpm csvq <file> [options]     # from app/
node src/cli.ts <file> [options]
```

Every example below is a real run from `app/`, pasted from its output.

## Printing a file

```console
$ node src/cli.ts fixtures/basic.csv
id,name,city,amount
1,Aiko,Osaka,1200
2,Ben,Tokyo,800
3,Chika,Osaka,450
4,Dan,Nagoya,2000
5,Emi,Tokyo,300
```

## Choosing columns

`--select` prints the columns in the order you ask for, not the order in the file.

```console
$ node src/cli.ts fixtures/basic.csv --select city,name
city,name
Osaka,Aiko
Tokyo,Ben
Osaka,Chika
Nagoya,Dan
Tokyo,Emi
```

## Filtering rows

```console
$ node src/cli.ts fixtures/basic.csv --where city=Osaka
id,name,city,amount
1,Aiko,Osaka,1200
3,Chika,Osaka,450
```

Repeat `--where` to require every condition. Ben is in Tokyo, so asking for both leaves nothing:

```console
$ node src/cli.ts fixtures/basic.csv --where city=Osaka --where name=Ben
id,name,city,amount
```

## Counting and summing

```console
$ node src/cli.ts fixtures/basic.csv --count
5
```

```console
$ node src/cli.ts fixtures/basic.csv --sum amount --where city=Osaka
1650
```

## JSON output

`--format json` prints an array of objects keyed by the header. This is also the clearest way to see
how quoting is read: the comma inside `"Suzuki, Taro"`, the doubled quote that becomes one, the line
break inside a field, and the empty quoted field.

```console
$ node src/cli.ts fixtures/quoted.csv --format json
[
  {
    "id": "1",
    "name": "Suzuki, Taro",
    "note": "says \"hello\""
  },
  {
    "id": "2",
    "name": "Kato",
    "note": "two\nlines"
  },
  {
    "id": "3",
    "name": "",
    "note": "plain"
  }
]
```

## Errors and exit codes

`0` success, `1` a usage error, `2` an input error. Messages go to stderr, so a redirected stdout
stays clean. A usage error names the option or column:

```console
$ node src/cli.ts fixtures/basic.csv --nope; echo "exit $?"
csvq: unknown option "--nope"
exit 1
```

```console
$ node src/cli.ts fixtures/basic.csv --select nope; echo "exit $?"
csvq: unknown column "nope" in --select
exit 1
```

```console
$ node src/cli.ts fixtures/basic.csv --count --format json; echo "exit $?"
csvq: --count cannot be combined with --format json
exit 1
```

An input error names the line it applies to. `fixtures/broken.csv` opens a quote on line 3 and never
closes it:

```console
$ node src/cli.ts fixtures/broken.csv; echo "exit $?"
csvq: cannot read "fixtures/broken.csv": unterminated quote on line 3
exit 2
```

```console
$ node src/cli.ts fixtures/nope.csv; echo "exit $?"
csvq: cannot read "fixtures/nope.csv": no such file
exit 2
```

```console
$ node src/cli.ts fixtures/basic.csv --sum name; echo "exit $?"
csvq: cannot sum "name": "Aiko" on line 2 is not a number
exit 2
```

## Usage

```console
$ node src/cli.ts --help
csvq — print selected columns, filtered rows, a count or a sum from a CSV file

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
```

## Development

```
pnpm install
pnpm test        # vitest
pnpm lint        # biome
pnpm typecheck   # tsc --noEmit
```
