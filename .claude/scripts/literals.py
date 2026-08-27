# Literal conservation for the .claude/ tree: extract, merge, check.
#
# A literal is a value a rule names that a later reader must still be able to
# find: a tolerance, a version bound, an error class name, a file path, an
# editor extension id. Three of the nineteen rules lost in the previous
# restructure were literals buried inside an example, so a machine check for
# them is the cheapest real gate available.
#
# One module, three subcommands, because all three share the same notion of
# "does this literal appear in the tree" and two implementations of that would
# drift:
#
#   extract  seed the list by regex over the BEFORE files at a pinned ref
#   merge    fold in the `literals` column of plans/ledger/before-*.tsv
#   check    assert every literal in the list still appears in the tree
#
# WHITESPACE NORMALISATION is the reason this is Python and not grep. Markdown
# prose wraps, and a restructure re-wraps it constantly. The source may hold
#
#     present tense: "Clip weights to a
#     range", not "Clipping of weights"
#
# while the literal recorded for it is `Clip weights to a range`. Comparing raw
# bytes reports a loss that never happened. Both sides therefore collapse every
# run of whitespace to one space before comparison, which makes the check
# immune to re-wrapping - the single most common edit a restructure makes.
#
# Usage:
#   python .claude/scripts/literals.py extract [--ref 45e8751]
#   python .claude/scripts/literals.py merge [--dry-run]
#   python .claude/scripts/literals.py check

import argparse
import csv
import glob
import os
import re
import subprocess
import sys

LEDGER = "plans/ledger"
LIST = os.path.join(LEDGER, "literals.txt")
REJECTS = os.path.join(LEDGER, "literals-rejected.txt")
RETIRED = os.path.join(LEDGER, "literals-retired.txt")

# Section 5 rows the user approved for deletion. A3, A4 and C3 were considered
# and KEPT, so citing one of them to retire a literal is a mistake, not an
# approval, and `check` refuses it.
APPROVED_DELETIONS = {
    "A1", "A2", "A5", "A6",
    "B1", "B2", "B3", "B4", "B5", "B6", "B7",
    "C1", "C2",
}
SEARCH_ROOTS = ["CLAUDE.md", ".claude"]
MIN_LEN = 3

BEFORE_FILES = [
    "CLAUDE.md",
    ".claude/rules/code-style.md",
    ".claude/rules/engineering-preferences.md",
    ".claude/rules/function-documentation.md",
    ".claude/rules/github-strategy.md",
    ".claude/rules/r-package-conventions.md",
    ".claude/rules/surveywts-conventions.md",
    ".claude/rules/testing-standards.md",
    ".claude/rules/testing-surveywts.md",
]

RULES = [
    ("class", re.compile(r"\bsurveywts_(?:error|warning)_[a-z0-9_]+")),
    ("class", re.compile(r"\bsurveycore_(?:error|warning)_[a-z0-9_]+")),
    ("s7class", re.compile(r"\bsurvey_(?:base|taylor|nonprob|replicate)\b")),
    ("version", re.compile(r"\b[A-Za-z][A-Za-z0-9.]* \(>= [0-9][0-9.]*\)")),
    ("number", re.compile(r"\b[0-9]+(?:\.[0-9]+)?e-?[0-9]+\b")),
    ("number", re.compile(r"\b[0-9]+\.[0-9]+\b")),
    ("number", re.compile(r"\b[0-9]+%")),
    ("number", re.compile(r"\b[0-9]+L\b")),
    ("number", re.compile(r"=\s*(-?[0-9]+(?:\.[0-9]+)?)\b")),
    ("number", re.compile(r"~?([0-9]{2,4}) characters")),
    ("path", re.compile(r"\.claude/[A-Za-z0-9_./*-]+")),
    ("path", re.compile(r"\.github/[A-Za-z0-9_./-]+")),
    ("path", re.compile(r"\btests/testthat/[A-Za-z0-9_.*-]+")),
    ("path", re.compile(r"\bplans/[A-Za-z0-9_./-]+\.md")),
    ("path", re.compile(r"\bR/[A-Za-z0-9_-]+\.R\b")),
    ("path", re.compile(r"\b[A-Za-z0-9_-]+\.(?:toml|yaml|yml|Rd|lock)\b")),
    ("path", re.compile(r"\b(?:NAMESPACE|DESCRIPTION|\.editorconfig|\.lintr|\.Rbuildignore)\b")),
    ("tag", re.compile(r"@[a-zA-Z][a-zA-Z0-9]*")),
    ("rd", re.compile(r"\\(?:describe|item|eqn|deqn|dontrun|code|link)\{\}?")),
    ("fn", re.compile(r"\b(?:[A-Za-z][A-Za-z0-9_.]*::)?\.?[A-Za-z][A-Za-z0-9_.]*\(\)")),
    ("git", re.compile(r"\b(?:feature|fix|hotfix|docs|test|chore|refactor|perf|feat)/")),
    ("git", re.compile(r"\bX\.Y\.Z(?:\.9000)?\b")),
    ("git", re.compile(r"\bv[0-9]+\.[0-9]+\.[0-9]+\b")),
    ("git", re.compile(r"--(?:as-cran|no-manual|oneline)\b")),
    ("git", re.compile(r"R-CMD-check / [a-z-]+ \([a-z]+\)")),
    ("setting", re.compile(r"\b(?:line-width|indent-width|indent_size|indent_style|end_of_line|charset)\s*=\s*[A-Za-z0-9-]+")),
    ("setting", re.compile(r"\bPosit\.air-vscode\b")),
    ("setting", re.compile(r"\beditor\.(?:formatOnSave|defaultFormatter)\b")),
    ("setting", re.compile(r"\bset\.seed\(seed\)")),
]

# A sentinel between files so a normalised literal cannot match across a file
# boundary and report a phantom hit.
BREAK = " \x00FILEBREAK\x00 "


def norm(s):
    """Collapse every run of whitespace to one space. See module docstring."""
    return " ".join(s.split())


_corpus = None


def corpus():
    """The whole search surface, normalised, as one string."""
    global _corpus
    if _corpus is not None:
        return _corpus
    parts = []
    for root in SEARCH_ROOTS:
        if os.path.isfile(root):
            paths = [root]
        else:
            paths = [
                os.path.join(d, f)
                for d, _, files in os.walk(root)
                for f in files
            ]
        for p in sorted(paths):
            try:
                with open(p, encoding="utf-8", errors="replace") as fh:
                    parts.append(norm(fh.read()))
            except OSError:
                continue
    _corpus = BREAK.join(parts)
    return _corpus


def present(lit):
    return norm(lit) in corpus()


def read_list():
    header, lits = [], []
    if not os.path.exists(LIST):
        return header, lits
    with open(LIST, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\r\n")
            if line.startswith("#") or not line.strip():
                header.append(line)
            else:
                lits.append(line)
    return header, lits


def read_retired():
    """Literals removed by an approved deletion, as {literal: approval-row}.

    Returns (retired, problems). A problem is a row that must not be honoured:
    a missing or unapproved approval column, or a literal that was never in
    literals.txt. Honouring either would let this file become the back door
    that quietly shrinks the contract.
    """
    retired, problems = {}, []
    if not os.path.exists(RETIRED):
        return retired, problems
    tracked = set(norm(l) for l in read_list()[1])
    with open(RETIRED, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\r\n")
            if not line.strip() or line.startswith("#"):
                continue
            parts = line.split("\t")
            lit = parts[0]
            row = parts[1].strip() if len(parts) > 1 else ""
            if not row:
                problems.append(f"line {n}: no approval named for {lit!r}")
                continue
            if row not in APPROVED_DELETIONS:
                problems.append(
                    f"line {n}: {lit!r} cites {row}, which was not approved "
                    f"for deletion")
                continue
            if norm(lit) not in tracked:
                problems.append(
                    f"line {n}: {lit!r} is not in {LIST}, so it was never "
                    f"tracked")
                continue
            retired[norm(lit)] = row
    return retired, problems


# --- extract --------------------------------------------------------------

def cmd_extract(args):
    found = {}
    for path in BEFORE_FILES:
        try:
            text = subprocess.run(
                ["git", "show", f"{args.ref}:{path}"],
                capture_output=True, text=True, check=True, encoding="utf-8",
            ).stdout
        except subprocess.CalledProcessError:
            print(f"warning: cannot read {args.ref}:{path}", file=sys.stderr)
            continue
        for category, pattern in RULES:
            for m in pattern.finditer(text):
                lit = (m.group(1) if m.lastindex else m.group(0)).strip()
                if len(lit) < MIN_LEN:
                    continue
                found.setdefault(lit, category)

    by_cat = {}
    for lit, cat in found.items():
        by_cat.setdefault(cat, []).append(lit)

    os.makedirs(LEDGER, exist_ok=True)
    with open(LIST, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Literal list for check-literals.sh\n")
        fh.write(f"# Machine-extracted from {args.ref} by literals.py extract.\n")
        fh.write("# Comparison collapses whitespace on both sides, so a literal\n")
        fh.write("# that the source line-wraps still matches. One per line.\n")
        for cat in sorted(by_cat):
            fh.write(f"\n# --- {cat} ({len(by_cat[cat])}) ---\n")
            for lit in sorted(by_cat[cat]):
                fh.write(lit + "\n")

    print(f"wrote {LIST}")
    print(f"{len(found)} distinct literals")
    for cat in sorted(by_cat):
        print(f"  {cat:<10} {len(by_cat[cat]):>4}")
    return 0


# --- merge ----------------------------------------------------------------

def cmd_merge(args):
    _, existing = read_list()
    existing_norm = {norm(x) for x in existing}

    cands = {}
    for path in sorted(glob.glob(os.path.join(LEDGER, "before-*.tsv"))):
        with open(path, encoding="utf-8", newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            if not reader.fieldnames or "literals" not in reader.fieldnames:
                print(f"warning: {path} lacks a literals column", file=sys.stderr)
                continue
            for row in reader:
                for lit in (row.get("literals") or "").split(";"):
                    lit = lit.strip().strip("`")
                    if len(lit) >= MIN_LEN:
                        cands.setdefault(lit, set()).add(os.path.basename(path))

    new_ok, rejected, already = [], [], 0
    for lit in sorted(cands):
        if norm(lit) in existing_norm:
            already += 1
        elif present(lit):
            new_ok.append(lit)
            existing_norm.add(norm(lit))
        else:
            rejected.append((lit, sorted(cands[lit])))

    print(f"candidates from TSVs      {len(cands)}")
    print(f"  already in the list     {already}")
    print(f"  admitted (found today)  {len(new_ok)}")
    print(f"  rejected (not found)    {len(rejected)}")
    print(f"list size {len(existing)} -> {len(existing) + len(new_ok)}")

    if args.dry_run:
        print("\ndry run: nothing written")
        for lit, src in rejected:
            print(f"  REJECT  {lit!r}  ({', '.join(src)})")
        return 0

    with open(LIST, "a", encoding="utf-8", newline="\n") as fh:
        fh.write(f"\n# --- agent-extracted ({len(new_ok)}) ---\n")
        fh.write("# From the `literals` column of plans/ledger/before-*.tsv.\n")
        fh.write("# Each confirmed present in the tree before admission.\n")
        for lit in new_ok:
            fh.write(lit + "\n")

    with open(REJECTS, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("# Recorded by an inventory agent, absent from the untouched\n")
        fh.write("# tree even after whitespace normalisation. Almost always a\n")
        fh.write("# normalised call - .get_history() for .get_history(data) - or\n")
        fh.write("# a paraphrase. Review; correct and promote any that is real.\n\n")
        for lit, src in rejected:
            fh.write(f"{lit}\t{','.join(src)}\n")

    print(f"\nwrote {LIST}")
    print(f"wrote {REJECTS}  ({len(rejected)} to review)")
    return 0


# --- check ----------------------------------------------------------------

def cmd_check(args):
    _, lits = read_list()
    if not lits:
        print(f"FAIL  literals: list is empty or missing: {LIST}")
        return 1

    retired, problems = read_retired()
    if problems:
        print(f"FAIL  retired: {len(problems)} bad row(s) in {RETIRED}")
        for pr in problems:
            print(f"        {pr}")
        return 1

    active = [l for l in lits if norm(l) not in retired]
    missing = [l for l in active if not present(l)]

    # A retired literal that is still in the tree means the retirement is
    # stale: the deletion did not happen, or the value came back somewhere
    # else. Report it so the register cannot rot unnoticed, but do not fail -
    # a value reappearing is not a loss.
    back = [l for l in lits if norm(l) in retired and present(l)]

    if missing:
        print(f"FAIL  literals: {len(missing)} of {len(active)} not found")
        for m in missing:
            print(f"        {m}")
        return 1

    tail = f" ({len(retired)} removed on purpose)" if retired else ""
    print(f"PASS  literals: {len(active)} of {len(active)} found{tail}")
    for b in back:
        print(f"NOTE  retired but still present: {b} ({retired[norm(b)]})")
    return 0


def main():
    # The console on Windows defaults to cp1252, which cannot encode the
    # arrows, dashes and quotes that appear inside these literals. Printing a
    # missing literal then raises UnicodeEncodeError and the run dies partway
    # through the list - the gate fails to report the very failures it exists
    # to report. Force UTF-8, and fall back to replacing the odd character
    # rather than losing the report.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("extract"); e.add_argument("--ref", default="45e8751")
    m = sub.add_parser("merge"); m.add_argument("--dry-run", action="store_true")
    sub.add_parser("check")
    args = ap.parse_args()
    return {"extract": cmd_extract, "merge": cmd_merge, "check": cmd_check}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
