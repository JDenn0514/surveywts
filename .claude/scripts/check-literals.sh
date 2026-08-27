#!/usr/bin/env bash
# Conservation checks for the .claude/ tree.
#
# Two phases, both deterministic and both re-runnable forever:
#
#   1. LITERALS  - every literal value recorded in the literal list must still
#                  appear somewhere in the search surface. This is the check a
#                  line count cannot do. It catches a tolerance, a version
#                  bound, an error class name, or an editor extension id that a
#                  restructure quietly dropped.
#
#   2. CITATIONS - every .claude/ path cited anywhere in the repo must resolve,
#                  and no @-prefixed force-load link may appear. This catches a
#                  live skill left pointing at a file that moved.
#
# Usage:
#   bash .claude/scripts/check-literals.sh [literals-file]
#
# Default literals file: plans/ledger/literals.txt
# Exit 0 = both phases clean. Exit 1 = at least one failure, listed on stdout.

set -uo pipefail

LITERALS="${1:-plans/ledger/literals.txt}"
ALLOWLIST="plans/ledger/citation-allowlist.txt"

# Where a literal may live. The whole point of the standards tier is that a
# rule can move within this surface without being lost, so search all of it.
SEARCH_ROOTS=(CLAUDE.md .claude)

# Where a broken citation actually hurts. Only files an agent loads or reads
# are scanned. A planning document under plans/ legitimately names files that
# do not exist yet, so plans/ is deliberately out of scope here.
CITATION_ROOTS=(CLAUDE.md .claude)

fail=0

# --- Phase 1: literals ----------------------------------------------------

if [[ ! -f "$LITERALS" ]]; then
  echo "FAIL  literals file not found: $LITERALS"
  echo "      run: python .claude/scripts/literals.py extract"
  exit 1
fi

# Delegated to literals.py. The comparison must collapse whitespace on both
# sides, because Markdown prose wraps and a restructure re-wraps it; a raw
# byte match would report a loss every time a paragraph reflowed. Doing that
# in bash would mean a second implementation of the rule, free to drift from
# the one `merge` uses to admit literals in the first place.
if ! python .claude/scripts/literals.py check; then
  fail=1
fi

# --- Phase 2: citations ---------------------------------------------------

# Every .claude/... path mentioned anywhere must exist. A trailing directory
# reference (.claude/rules/) counts as resolved if the directory exists.
bad_paths=0
bad_list=()

while IFS= read -r p; do
  [[ -z "$p" ]] && continue
  p="${p%.}"          # drop a sentence-ending period
  p="${p%,}"
  p="${p%\`}"
  [[ -z "$p" ]] && continue
  # A match ending in - or _ is a truncation: the source wrote a placeholder
  # such as .claude/rules/testing-{package}.md and the regex stopped at the
  # brace. Not a citation.
  [[ "$p" == *- || "$p" == *_ ]] && continue
  # Skip anything on the allowlist.
  if [[ -f "$ALLOWLIST" ]] && grep -qxF -e "$p" "$ALLOWLIST" 2>/dev/null; then
    continue
  fi
  if [[ "$p" == */ ]]; then
    [[ -d "${p%/}" ]] && continue
  else
    [[ -e "$p" ]] && continue
    [[ -d "$p" ]] && continue
  fi
  # A glob such as .claude/skills/*.md resolves if anything matches.
  if [[ "$p" == *"*"* ]]; then
    # shellcheck disable=SC2086
    compgen -G "$p" > /dev/null && continue
  fi
  bad_paths=$((bad_paths + 1))
  bad_list+=("$p")
done < <(
  # Capture one character of left context so an absolute path such as
  # C:/Users/jdennen/.claude/projects/... can be told apart from a repo-relative
  # citation. A match preceded by / or \ belongs to somebody else's tree.
  grep -rhoE '(^|.)\.claude/[A-Za-z0-9_./-]+' "${CITATION_ROOTS[@]}" 2>/dev/null \
    | grep -vE '^[/\\]\.claude/' \
    | sed -E 's/^[^.]*\.claude/.claude/' \
    | sed 's/[.,`)]*$//' | sort -u
)

if (( bad_paths > 0 )); then
  fail=1
  echo "FAIL  citations: $bad_paths .claude/ path(s) do not resolve"
  for b in "${bad_list[@]}"; do
    printf '        %s\n' "$b"
  done
else
  echo "PASS  citations: every .claude/ path resolves"
fi

# No @-prefixed force-load links. These pull a file into context immediately
# and defeat the whole point of a read-on-demand tier.
forceload=$(grep -rn '@\.claude/' "${CITATION_ROOTS[@]}" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$forceload" != "0" ]]; then
  fail=1
  echo "FAIL  force-load: $forceload @-prefixed .claude/ link(s)"
  grep -rn '@\.claude/' "${CITATION_ROOTS[@]}" 2>/dev/null | sed 's/^/        /'
else
  echo "PASS  force-load: no @-prefixed .claude/ links"
fi

# --- Phase 3: standards reachability --------------------------------------
# Every file in .claude/standards/ must be named by at least one agent
# definition, skill, or always-loaded rule. An unreachable standards file is a
# silent loss: the rules are still on disk and nothing ever reads them.

if [[ -d .claude/standards ]]; then
  unreachable=0
  unreachable_list=()
  while IFS= read -r f; do
    base=$(basename "$f")
    hits=$(grep -rlF "standards/$base" CLAUDE.md .claude/agents .claude/skills .claude/rules 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$hits" == "0" ]]; then
      unreachable=$((unreachable + 1))
      unreachable_list+=("$base")
    fi
  done < <(find .claude/standards -name '*.md' 2>/dev/null)

  if (( unreachable > 0 )); then
    fail=1
    echo "FAIL  reachability: $unreachable standards file(s) named by nothing"
    for u in "${unreachable_list[@]}"; do
      printf '        %s\n' "$u"
    done
  else
    echo "PASS  reachability: every standards file is named somewhere"
  fi
else
  echo "SKIP  reachability: .claude/standards/ does not exist yet"
fi

# --------------------------------------------------------------------------

if (( fail )); then
  echo
  echo "RESULT  FAIL"
  exit 1
fi
echo
echo "RESULT  PASS"
exit 0
