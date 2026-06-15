# PR 5 Audit — Round 2

## Verdict: PASS

All five BLOCK items from round 1 are resolved. All profile gates pass.

---

## Gate results

| # | Gate | Result | Notes |
|---|------|--------|-------|
| 1 | `devtools::document()` — NAMESPACE/man/ unchanged | PASS | `git diff --exit-code NAMESPACE man/` exits 0; `export(poststratify)` in NAMESPACE; `man/poststratify.Rd` present; `man/calibrate_poststrat.Rd` absent |
| 2 | `devtools::test()` — all tests pass | PASS | 2933 pass, 0 fail, 3 skip |
| 3 | `devtools::run_examples()` — clean | PASS | 0 errors, 22 benign warnings |
| 4 | `R CMD build .` — tarball produced | PASS | `surveywts_0.2.0.9000.tar.gz` |
| 5 | `R CMD check --as-cran` — 0 errors/warnings | PASS | 2 pre-approved NOTEs only (`CRAN incoming feasibility`, `future file timestamps`) |
| 6 | `pkgdown::build_site()` | SKIPPED — pre-pkgdown scope per test-spec |
| 7 | `covr::package_coverage()` — overall >= 95% | PASS | 97.95% overall |
| 7b | `covr` — `poststratify.R` >= 98% | PASS | 100% (133/133 coverable lines) |

---

## BLOCK-1 fix verification — NAMESPACE/man drift

RESOLVED. `NAMESPACE` now exports `poststratify` (line 26). `man/poststratify.Rd` is committed. `man/calibrate_poststrat.Rd` is absent. `devtools::document()` produces no diff.

## BLOCK-2 fix verification — coverage

RESOLVED. `poststratify.R` coverage is 100% (133/133 lines). Three new test blocks cover the previously uncovered lines:
- `test-04-poststratify.R:1386` — `type = "prop"` branch in replicate loop (line 430–431 of source)
- `test-04-poststratify.R:1360` — degenerate cell guard `n_hat_c <= 0` (lines 442–446)
- `test-04-poststratify.R:1360` — `tryCatch` error handler (lines 454–473)

## BLOCK-3 fix verification — EC6 value assertion

RESOLVED. `test-04-poststratify.R:1285` — new test block iterates over `seq_along(cf)`, computes `ht_est <- sum(pre_wts[cell_mask])` for each cell, and asserts `expect_equal(cf[[i]], targets$target[[i]] / ht_est, tolerance = 1e-10)`. Tolerance matches spec requirement exactly.

## BLOCK-4 fix verification — CX4 distinct operations

RESOLVED. `test-04-poststratify.R:1314` — new test block calls `calibrate_linear`, `calibrate_logit`, `calibrate_rake`, and `poststratify` with `suppressWarnings`, extracts the `operation` field from the last history entry for each result, and asserts both `expect_length(unique(ops), 4L)` and `expect_true(all(c("calibrate_linear", "calibrate_logit", "calibrate_rake", "poststratify") %in% ops))`.

## BLOCK-5 fix verification — W1 and W2 warning tests

RESOLVED.

**W1** (`surveywts_warning_srs_no_weights`):
- `R/poststratify.R:253` — `cli::cli_warn(..., class = "surveywts_warning_srs_no_weights")` emitted for plain `data.frame` + `weights = NULL`
- `test-04-poststratify.R:1343` — `expect_warning(result <- poststratify(...), class = "surveywts_warning_srs_no_weights")` followed by `test_invariants(result)`

**W2** (`surveywts_warning_replicate_calibration_failed`):
- Implementation already present at `R/poststratify.R:470`
- `test-04-poststratify.R:1360` — zeroes the first replicate column's weights for the `"55+"` cells, asserts `expect_warning(class = "surveywts_warning_replicate_calibration_failed")`, then asserts full-sample weights are still positive and `result@calibration$replicate_converged[[first_rep_col]]` is `FALSE`

---

## Per-test result table

| Test | Got | Expected | Tolerance | Pass |
|------|-----|----------|-----------|------|
| EC6: `cell_factors[i] == target[i] / sum(pre_wts[cell_mask])` | computed per cell | `targets$target[[i]] / ht_est` | `1e-10` | PASS |
| CX4: 4 distinct operation strings | `c("calibrate_linear","calibrate_logit","calibrate_rake","poststratify")` | 4 distinct strings | exact | PASS |
| W1: `expect_warning(class = "surveywts_warning_srs_no_weights")` | warning emitted | `surveywts_warning_srs_no_weights` | exact class | PASS |
| W2: `expect_warning(class = "surveywts_warning_replicate_calibration_failed")` | warning emitted | `surveywts_warning_replicate_calibration_failed` | exact class | PASS |
| `poststratify.R` coverage | 100% | >= 98% | — | PASS |
| Overall coverage | 97.95% | >= 95% | — | PASS |

---

## CRAN cookbook scan

No violations in `R/poststratify.R`:
- No `T`/`F` abbreviations
- No `set.seed()`
- No bare `print()`/`cat()`
- No `options(warn = -1)`
- No `installed.packages()`
- No `<<-`
- No `@importFrom`
- No `calibrate_poststrat` in functional code (`R/` or `tests/`) — comments only

---

## Before/After comparison

| Metric | Before PR (round 1) | After PR (round 2) | Delta |
|--------|---------------------|--------------------|-------|
| Tests passing | 2910 | 2933 | +23 |
| Tests failing | 0 | 0 | 0 |
| R CMD check errors | 0 | 0 | 0 |
| R CMD check warnings | 0 | 0 | 0 |
| R CMD check NOTEs | 2 | 2 | 0 |
| Overall coverage | 97.55% | 97.95% | +0.40% |
| `poststratify.R` coverage | 95.45% | 100% | +4.55% |
