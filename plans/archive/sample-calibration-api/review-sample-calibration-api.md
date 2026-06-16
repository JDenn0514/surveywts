# Review — sample-calibration-api PR 1 (Third Reviewer Cycle)

**Date:** 2026-06-12
**Cycle:** 3
**Verdict: PASS**

---

## Prior BLOCK items — confirmed resolved

### BLOCK-1: `calibrate_to_estimate()` weight_stats block

`test-sample-calibration.R:600–622` now contains a dedicated test block that
asserts `"weight_stats" %in% names(last)`, `names(last$weight_stats) ==
c("before", "after")`, `names(last$weight_stats$before) == expected_keys`
(all 11 keys), and `expect_false(last$weight_stats$before$mean ==
last$weight_stats$after$mean)`. Resolved.

### BLOCK-2: `calibrate_to_survey()` weight_stats incomplete assertions

`test-sample-calibration.R:79–100` now asserts
`expect_identical(names(last$weight_stats$before), expected_keys)` (11 keys),
`expect_identical(names(last$weight_stats$after), expected_keys)`, and
`expect_false(last$weight_stats$before$mean == last$weight_stats$after$mean)`.
Resolved.

---

## Lens 1 — Spec coverage

Every function contract in `spec-sample-calibration-api.md` is covered by a
test row in `audit.md`. All 7 errors for `calibrate_to_survey()` and all 13
errors for `calibrate_to_estimate()` are confirmed present. History field
contracts, validation order, `control_col_matches`/`col_selection` exclusion,
and `reference_design` proxy storage are all tested. No gaps.

## Lens 2 — Test-spec coverage

All scenarios in `test-spec-sample-calibration-api.md` are present in
`test-sample-calibration.R`. Dual pattern (`expect_error(class=)` +
`expect_snapshot`) is complete for all required error paths. Both weight_stats
blocks now satisfy the exact assertions specified in the test-spec.

## Lens 3 — Cross-consistency

Audit verdict is PASS with FAIL 0 and 132 sample-calibration tests passing.
`weight_stats` is produced by `utils.R:.make_history_entry()` (line 583–585)
as `list(before = before_stats, after = after_stats)` fed by
`.compute_weight_stats()` calls captured before and after the svrep call in
both implementation files. The `before`/`after` key names match what tests
access. Tolerances in the test file (1e-8 numerical identity, 1e-6 calibration
constraints) match `test-spec-sample-calibration-api.md §Tolerances` exactly.
No relaxation.

## Lens 4 — Scope discipline

Write surface in `implementation-sample-calibration-api.md` matches the git
working tree. Files touched: `R/calibrate_to_survey.R`,
`R/calibrate_to_estimate.R`, `tests/testthat/helper-test-data.R`,
`tests/testthat/test-sample-calibration.R`,
`tests/testthat/_snaps/sample-calibration.md`,
`tests/testthat/_snaps/replicate-print.md` (date-stamp only, documented),
`plans/error-messages.md`, `man/calibrate_to_survey.Rd`,
`man/calibrate_to_estimate.Rd`, `NAMESPACE`,
`changelog/nonresponse/feature-sample-calibration-api.md`. No extra source
files. No missing required files.

## Lens 5 — CRAN cookbook

`audit.md §CRAN Cookbook Scan` shows no violations. Audit verdict is PASS
with cookbook violations absent.

## Lens 6 — Coverage floor

Coverage 97.90% (above the 95% gate). Drop from baseline 98.35% is 0.45%,
below the 0.5% HOLD threshold. No regression in new lines. Floor met.

## Lens 7 — Comprehension alignment

No `comprehension-sample-calibration-api.md` present. Lens not applicable.

---

## Verdict: PASS

All prior BLOCK items are resolved. Convergence check, tolerance integrity,
scope discipline, CRAN cookbook, coverage floor, and audit verdict are all
clean.
