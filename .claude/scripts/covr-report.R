# Coverage report for the pipeline's covr gate.
#
# Prints, in this order:
#   COVERAGE_PCT=<package total>
#   CHANGED_FILE_PCT <file>=<pct>        one line per changed R/ file
#   UNCOVERED_LINE <file>:<line>         one line per zero-hit line in those files
#   UNCOVERED_COUNT=<n>
#
# The changed-file list arrives in CHANGED_R_FILES as a comma-separated string.
# When it is empty only the package total is printed.
#
# Whole-file percentages answer "did this file regress"; the UNCOVERED_LINE list
# is what answers the plan's real question — whether any line this PR ADDED is
# untested. Cross-reference those line numbers against `git diff` to tell an
# added line from a pre-existing one.
#
# NOT_CRAN=true matches CI and stops skip_on_cran() blocks from being
# skipped, which would understate coverage.

cov <- covr::package_coverage()
cat(sprintf("COVERAGE_PCT=%.2f\n", covr::percent_coverage(cov)))

changed <- Sys.getenv("CHANGED_R_FILES")
if (!nzchar(changed)) {
  quit(save = "no", status = 0)
}

files <- setdiff(trimws(strsplit(changed, ",", fixed = TRUE)[[1]]), "")
if (length(files) == 0L) {
  quit(save = "no", status = 0)
}

fc <- covr::coverage_to_list(cov)$filecoverage
for (f in files) {
  pct <- if (f %in% names(fc)) sprintf("%.2f", fc[[f]]) else "NA"
  cat(sprintf("CHANGED_FILE_PCT %s=%s\n", f, pct))
}

df <- as.data.frame(cov)
# covr's data frame names the file column "filename" in current releases;
# fall back to whatever column holds the path if that ever changes.
fcol <- if ("filename" %in% names(df)) "filename" else names(df)[1]
lcol <- if ("first_line" %in% names(df)) "first_line" else "line"

hit <- df[[if ("value" %in% names(df)) "value" else "coverage"]]
sel <- df[[fcol]] %in% files & hit == 0
uncovered <- df[sel, c(fcol, lcol), drop = FALSE]

if (nrow(uncovered) > 0L) {
  uncovered <- uncovered[order(uncovered[[fcol]], uncovered[[lcol]]), , drop = FALSE]
  for (i in seq_len(nrow(uncovered))) {
    cat(sprintf(
      "UNCOVERED_LINE %s:%s\n",
      uncovered[[fcol]][i],
      uncovered[[lcol]][i]
    ))
  }
}
cat(sprintf("UNCOVERED_COUNT=%d\n", nrow(uncovered)))
