# Implementation: PR 7 — calibrate_to_survey / calibrate_to_estimate edge case tests

## Write surface

Files modified:
- `tests/testthat/test-sample-calibration.R` — 3 new test blocks appended (sections 27–28)
- `tests/testthat/_snaps/sample-calibration.md` — 1 new snapshot appended automatically
- `NEWS.md` — 1 entry added under development heading

No production code files were modified.

## Summary

- Added test for `calibrate_to_survey()` with `method = "logit"`, exercising the
  `"logit"` branch of `.method_to_calfun()` in `R/calibrate-utils.R` (lines 870–871).
- Added test for `calibrate_to_estimate()` with `method = "logit"` and finite bounds
  `c(0.01, 100)`, exercising the same `.method_to_calfun()` branch via the svrep path.
- Added dual-pattern test (class= + snapshot) for `calibrate_to_estimate()` when
  `vcov_estimate` is a vector (not a matrix), covering the `is.null(vcov_dim)` branch
  at line 364 of `R/calibrate_to_estimate.R` with error class
  `surveywts_error_vcov_dimension_mismatch`.
- Task 7.1 (`.compute_control_totals()` error at lines 781–797) was skipped because
  those lines are defensively unreachable: `.check_control_levels()` at step 9 of
  `calibrate_to_survey()` performs the same level-existence check and always fires
  first; if it passes, `.compute_control_totals()` cannot encounter a missing level.
  The existing section 20 tests cover `.check_control_levels()` thoroughly.

## Task checklist

- [x] Task 7.1 (CONDITIONAL) — SKIPPED (lines 781–797 are defensively unreachable
      via public API; `.check_control_levels()` fires first and covers the same
      condition; existing section 20 tests cover that path)
- [x] Task 7.2a — `calibrate_to_survey()` with `method = "logit"`
- [x] Task 7.2b — `calibrate_to_estimate()` with `method = "logit"`
- [x] Task 7.3 — `calibrate_to_estimate()` rejects non-matrix `vcov_estimate`

## HOLDs raised

None.

## CRAN compliance checklist

1. TRUE/FALSE used throughout (no T/F) — N/A (test-only PR, no production code)
2. `::` for external calls — N/A (test-only)
3. No bare `print()`/`cat()` — N/A
4. `seed = NULL` on randomness — N/A
5. `on.exit()` restoring state — N/A
6. `tempdir()` with cleanup — N/A
7. ≤2 cores in examples/tests — N/A
8. `devtools::document()` run — N/A (no roxygen changes)
9. `requireNamespace()` not `installed.packages()` — N/A
10. All `cli_abort()`/`cli_warn()` have `class=` — N/A (test-only)

## Notes for tester

- The `calibrate_to_estimate()` logit test uses `bounds = c(0.01, 100)` because
  svrep's `calibrate_to_estimate()` requires finite bounds for logit calibration;
  the default `c(-Inf, Inf)` would cause svrep to error.
- The `.method_to_calfun()` function is in `R/calibrate-utils.R` (not in
  `R/calibrate_to_survey.R` as stated in the impl plan); both logit tests cover
  lines 870–871 of `calibrate-utils.R` indirectly.
- Full test run: 3448 PASS, 0 FAIL, 2 SKIP (both intentional skips unrelated
  to this PR).
