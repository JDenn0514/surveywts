#!/usr/bin/env bash
# Run all surveywts validation gates in order, log full output per gate,
# and print one compact summary. Built for the tester agent: ONE background
# call, one summary read, zero polling turns.
#
# Usage:
#   bash .claude/scripts/run-gates.sh <log-dir> [--skip-pkgdown] [--baseline]
#
#   --skip-pkgdown  Skip gate 6. Allowed ONLY under the skip conditions in
#                   r-package-profile.md (never when NAMESPACE changes).
#   --baseline      Run only gates 2 (tests) and 7 (coverage). For the
#                   orchestrator's Before-column capture on a clean tree.
#
# Exit code 0 = all gates PASS. The summary names the log file of any FAIL.
# Gate definitions live in r-package-profile.md §Validation commands.

set -u
LOGDIR="${1:?usage: run-gates.sh <log-dir> [--skip-pkgdown] [--baseline]}"
shift || true
SKIP_PKGDOWN=0
BASELINE=0
for a in "$@"; do
  case "$a" in
    --skip-pkgdown) SKIP_PKGDOWN=1 ;;
    --baseline)     BASELINE=1 ;;
  esac
done
mkdir -p "$LOGDIR"

SUMMARY=""
OVERALL=0

row() { SUMMARY="${SUMMARY}${1}\n"; }

fail_gate() { # name logfile note
  row "| $1 | FAIL | $3 — read $2 |"
  OVERALL=1
}

pass_gate() { # name note
  row "| $1 | PASS | $2 |"
}

# --- Gate 2: devtools::test() ------------------------------------------
gate_test() {
  local log="$LOGDIR/gate-2-test.log"
  NOT_CRAN=true Rscript -e 'devtools::test()' > "$log" 2>&1
  local line
  line=$(grep -E '\[ FAIL [0-9]+' "$log" | tail -1)
  local nfail
  nfail=$(printf '%s' "$line" | sed -E 's/.*FAIL ([0-9]+).*/\1/')
  if [ -n "$line" ] && [ "$nfail" = "0" ]; then
    pass_gate "devtools::test()" "$line"
  else
    fail_gate "devtools::test()" "$log" "${line:-no result line found}"
  fi
}

# --- Gate 7: coverage ----------------------------------------------------
gate_covr() {
  local log="$LOGDIR/gate-7-covr.log"
  # NOT_CRAN=true matches CI and stops skip_on_cran() blocks from being
  # skipped, which would understate coverage.
  # Report the package total AND per-file coverage plus uncovered line numbers
  # for the R/ files this branch changed. The plan states the bar as "98%+ on
  # the NEW code; blocked below 95%" — the package total alone cannot answer
  # that, so covr-report.R adds the per-file and per-line detail.
  local changed
  changed=$(git diff --name-only develop...HEAD -- 'R/*.R' 2>/dev/null | tr '\n' ',')
  NOT_CRAN=true CHANGED_R_FILES="$changed" \
    Rscript .claude/scripts/covr-report.R > "$log" 2>&1
  local pct
  pct=$(grep -oE 'COVERAGE_PCT=[0-9.]+' "$log" | tail -1 | cut -d= -f2)
  local nunc
  nunc=$(grep -oE 'UNCOVERED_COUNT=[0-9]+' "$log" | tail -1 | cut -d= -f2)
  local detail="${pct}%"
  if [ -n "$nunc" ]; then
    detail="${detail}; changed R/ files: $(grep -c '^CHANGED_FILE_PCT' "$log"), uncovered lines in them: ${nunc}"
  fi
  if [ -z "$pct" ]; then
    fail_gate "covr" "$log" "coverage did not run"
  elif awk "BEGIN{exit !($pct >= 95)}"; then
    pass_gate "covr" "$detail"
  else
    fail_gate "covr" "$log" "coverage ${pct}% is below the 95% floor"
  fi
}

# --- Gate 8: air format --check ----------------------------------------
gate_air() {
  local log="$LOGDIR/gate-8-air.log"
  if ! command -v air > /dev/null 2>&1; then
    echo "air is not on PATH" > "$log"
    fail_gate "air format --check" "$log" "air is not installed"
    return
  fi
  if air format --check . > "$log" 2>&1; then
    pass_gate "air format --check" "every R file is formatted"
  else
    local n
    n=$(grep -c '^Would reformat:' "$log")
    fail_gate "air format --check" "$log" "${n} file(s) need 'air format .'"
  fi
}

if [ "$BASELINE" = "1" ]; then
  gate_test
  gate_covr
else
  # --- Gate 1: document() + drift check --------------------------------
  log="$LOGDIR/gate-1-document.log"
  Rscript -e 'devtools::document()' > "$log" 2>&1
  if git diff --quiet -- NAMESPACE man/ 2>>"$log"; then
    pass_gate "devtools::document()" "no NAMESPACE/man drift"
  else
    git diff --stat -- NAMESPACE man/ >> "$log" 2>&1
    fail_gate "devtools::document()" "$log" "NAMESPACE/man drift (builder forgot document())"
  fi

  gate_test

  # --- Gate 3: run_examples() ------------------------------------------
  log="$LOGDIR/gate-3-examples.log"
  if NOT_CRAN=true Rscript -e 'devtools::run_examples()' > "$log" 2>&1; then
    pass_gate "run_examples()" "all examples ran"
  else
    fail_gate "run_examples()" "$log" "example error"
  fi

  # --- Gate 4: R CMD build ----------------------------------------------
  log="$LOGDIR/gate-4-build.log"
  rm -f ./*.tar.gz
  if R CMD build . > "$log" 2>&1 && ls ./*.tar.gz >/dev/null 2>&1; then
    TARBALL=$(ls -t ./*.tar.gz | head -1)
    pass_gate "R CMD build" "$TARBALL"
  else
    TARBALL=""
    fail_gate "R CMD build" "$log" "no tarball produced"
  fi

  # --- Gate 5: R CMD check --as-cran ------------------------------------
  log="$LOGDIR/gate-5-check.log"
  if [ -n "$TARBALL" ]; then
    # --no-manual mirrors CI (.github/workflows/R-CMD-check.yaml passes
    # c("--as-cran", "--no-manual")). Without it the PDF-manual step needs a
    # LaTeX toolchain; where none is installed it raises 1 ERROR + 1 WARNING
    # and leaves surveywts-manual.tex behind as a third NOTE — none of which
    # CI ever sees, and none of which a builder can fix.
    R CMD check --as-cran --no-manual "$TARBALL" > "$log" 2>&1
    CHECKDIR=$(ls -dt ./*.Rcheck 2>/dev/null | head -1)
    [ -n "$CHECKDIR" ] && cp "$CHECKDIR/00check.log" "$LOGDIR/gate-5-00check.log" 2>/dev/null
    status_line=$(grep -E '^Status:' "$log" | tail -1)
    if printf '%s' "$status_line" | grep -qE 'ERROR|WARNING'; then
      fail_gate "R CMD check --as-cran" "$LOGDIR/gate-5-00check.log" "$status_line"
    else
      pass_gate "R CMD check --as-cran" "${status_line:-Status line missing — verify log} (NOTEs need review per pre-approved list)"
    fi
    [ -n "$CHECKDIR" ] && rm -rf "$CHECKDIR"
    rm -f "$TARBALL"
  else
    fail_gate "R CMD check --as-cran" "$LOGDIR/gate-4-build.log" "skipped — build failed"
  fi

  # --- Gate 6: pkgdown ----------------------------------------------------
  if [ "$SKIP_PKGDOWN" = "1" ]; then
    row "| pkgdown | SKIPPED | scope (log skip reason in audit.md) |"
  else
    log="$LOGDIR/gate-6-pkgdown.log"
    if Rscript -e 'pkgdown::build_site(preview = FALSE)' > "$log" 2>&1; then
      pass_gate "pkgdown" "site built"
    else
      fail_gate "pkgdown" "$log" "site build error"
    fi
  fi

  gate_covr
  gate_air
fi

echo ""
echo "## Gate summary"
echo "| Gate | Result | Notes |"
echo "|---|---|---|"
printf "%b" "$SUMMARY"
echo ""
echo "Tree: $(git rev-parse 'HEAD^{tree}')"
echo "Logs: $LOGDIR"
[ "$OVERALL" = "0" ] && echo "ALL GATES PASS" || echo "GATE FAILURE(S) — read only the named log(s)"
exit $OVERALL
