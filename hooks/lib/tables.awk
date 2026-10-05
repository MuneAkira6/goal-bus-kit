# tables.awk — the one parser for judgment tables. The bus driver, the evidence gate and the selftests
# all go through it, so what the tests prove is what the hooks do.
#
#   OP=count     print how many rows of goal section GOAL still have an empty verdict
#   OP=countall  print "<goal> <count>" for every goal section that has empty verdicts
#   OP=check     print one line per evidence-rule violation; exit status 1 when there is any
#
# Portable across gawk and mawk: no interval expressions, no POSIX character classes and no
# gawk-only functions. (On mawk an interval regex quietly matches nothing, so every table would look
# empty and every check would pass.)
#
# A judgment table is a markdown table whose header row has one cell equal to VCOL_NAME and another
# that contains ECOL_NAME (both compared case-insensitively), followed by a separator row; any other
# table is ignored. A goal section opens at a "## G<n>[suffix]" heading and closes at the next "## "
# heading of any kind, so "###" subsections belong to their goal and an appendix never counts toward
# the last one.

function strip(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function canon(s) { gsub(/[ \t*_`]/, "", s); return toupper(s) }
# empty, a dash of any width, or N/A
function empty_cell(s) {
  s = strip(s)
  if (toupper(s) == "N/A") return 1
  return index("|-|—|–||", "|" s "|") > 0
}
function has_quote(s,    k) {
  for (k = 1; k <= nquote; k++) if (index(s, quote_mark[k])) return 1
  return 0
}
function hedge_in(s,    k, n, list, lower) {
  if (HEDGES == "") return ""
  lower = tolower(s)
  n = split(HEDGES, list, "|")
  for (k = 1; k <= n; k++) if (list[k] != "" && index(lower, tolower(list[k]))) return list[k]
  return ""
}
function report(row, msg) { printf "  %s:%d  [%s] %s\n", SRC, NR, row, msg; nbad++ }

BEGIN {
  mode = 0; nbad = 0; empties = 0; section = ""
  vname = tolower(VCOL_NAME); ename = tolower(ECOL_NAME)
  cite = (CITE == "") ? "" : canon(CITE)
  nbanned = (BANNED == "") ? 0 : split(BANNED, banned, "|")
  for (k = 1; k <= nbanned; k++) banned[k] = canon(banned[k])
  nquote = split("` \" “ ” 「 」 『 』", quote_mark, " ")
  # the verdicts that only need a reason, with what to say when the reason is missing
  needs_reason["BLOCKED"] = "BLOCKED must say what is missing."
  needs_reason["DEFERRED"] = "DEFERRED must name what it waits for (" WAIT_HINT ")."
}

/^## / {
  title = strip(substr($0, 4)); section = ""
  if (match(title, /^G[0-9]+[a-z]?/)) {
    name = substr(title, 1, RLENGTH); after = substr(title, RLENGTH + 1)
    if (after == "" || after ~ /^[^A-Za-z0-9]/) section = name
  }
  mode = 0
  next
}

!/^[ \t]*\|/ { mode = 0; next }

{
  row = $0
  gsub(/\\\|/, "\001", row)             # an escaped pipe stays inside its cell
  ncell = split(row, cell, "|")
  for (k = 1; k <= ncell; k++) { cell[k] = strip(cell[k]); gsub(/\001/, "|", cell[k]) }
  lo = 2; hi = ncell - 1
  if (hi < lo) { mode = 0; next }
  rule_row = 1
  for (k = lo; k <= hi; k++) if (cell[k] !~ /^:?-+:?$/) rule_row = 0

  # mode 0: expecting a header; 1: header found, expecting its separator; 2: inside a judgment
  # table; 3: inside some other table
  if (mode == 0) {
    vi = 0; ei = 0
    for (k = lo; k <= hi; k++) {
      head = cell[k]; gsub(/[*`]/, "", head); head = tolower(strip(head))
      if (head == vname) vi = k
      else if (index(head, ename)) ei = k
    }
    mode = (vi && ei) ? 1 : 3
    next
  }
  if (mode == 1) { mode = rule_row ? 2 : 3; next }
  if (mode == 3 || rule_row) next

  if (OP == "count" || OP == "countall") {
    if (section != "" && strip(cell[vi]) == "") {
      if (OP == "countall") empty_in[section]++
      else if (section == GOAL) empties++
    }
    next
  }

  verdict = canon(cell[vi]); evidence = cell[ei]
  if (verdict == "") next               # not judged yet, which is allowed
  label = (cell[lo] != "") ? cell[lo] : "row"
  for (k = 1; k <= nbanned; k++) {
    if (verdict != banned[k]) continue
    report(label, "the verdict \"" strip(cell[vi]) "\" is forbidden in this task (BANNED_VERDICTS). Use PASS, FAIL, BLOCKED or DEFERRED.")
    next
  }
  if (cite != "" && verdict == cite) {
    if (empty_cell(evidence)) report(label, CITE " needs evidence. Quote the observation, or downgrade to BLOCKED and say what is missing.")
    else if (!has_quote(evidence)) report(label, CITE " needs a quoted observation (backticks or quotation marks).")
    else if (!index(evidence, MARK_A) || !index(evidence, MARK_B)) report(label, CITE " needs both citations: \"" MARK_A "\" and \"" MARK_B "\" (the second must point outside this task).")
    next
  }

  kind = ""
  if (verdict ~ /^PASS/) kind = "PASS"
  else if (verdict ~ /^FAIL/) kind = "FAIL"
  else if (verdict ~ /^BLOCKED/) kind = "BLOCKED"
  else if (verdict ~ /^DEFERRED/) kind = "DEFERRED"

  if (kind == "PASS") {
    if (empty_cell(evidence)) { report(label, "PASS with an empty evidence cell. Quote the observation, or downgrade to BLOCKED and say what is missing."); next }
    hedge = hedge_in(evidence)
    if (hedge != "") { report(label, "the evidence says \"" hedge "\", which counts as unverified. Quote what you actually observed, or downgrade to BLOCKED."); next }
    if (!has_quote(evidence)) report(label, "PASS without a quote mark. Quote the observed output, text or hash (backticks or quotation marks).")
  } else if (kind == "FAIL") {
    lower = tolower(evidence)
    if (empty_cell(evidence) || !index(lower, tolower(EXP_WORD)) || !index(lower, tolower(ACT_WORD)))
      report(label, "a FAIL must read " EXP_WORD " \"<X>\" / " ACT_WORD " \"<Y>\". If you cannot write that, it is not a FAIL.")
  } else if (kind in needs_reason) {
    if (empty_cell(evidence)) report(label, needs_reason[kind])
  } else {
    report(label, "unknown verdict \"" strip(cell[vi]) "\". Use PASS, FAIL, BLOCKED or DEFERRED" (CITE != "" ? " (or " CITE ")" : "") ".")
  }
}

END {
  if (OP == "count") { print empties + 0; exit 0 }
  if (OP == "countall") { for (g in empty_in) print g, empty_in[g]; exit 0 }
  exit (nbad > 0) ? 1 : 0
}
