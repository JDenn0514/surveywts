# Implementation: BLOCK fix — duplicate `.validate_unit_scale()` removal

## Write surface

| File | Action |
|------|--------|
| `R/calibrate_to_survey.R` | Modified — removed duplicate `.validate_unit_scale()` definition (lines 477-526 of original) |
| `tests/testthat/_snaps/sample-calibration.md` | Modified — updated two snapshots to match canonical error message text |
| `NAMESPACE` | No change (devtools::document() produced identical output) |

## Summary

- Removed the duplicate `.validate_unit_scale()` function defined at the bottom of
  `R/calibrate_to_survey.R`. The canonical definition in `R/calibrate-utils.R` already
  handles the `NULL` case with an early return, so the duplicate was both redundant and
  harmful (its lack of a NULL guard caused 266 test failures across 13 test files).
- Both `calibrate_to_survey()` and `calibrate_to_estimate()` already guarded their
  calls with `if (!is.null(unit_scale))`, so removing the duplicate has no behavioral
  impact on valid inputs. The canonical version is now called directly.
- Updated two snapshots in `_snaps/sample-calibration.md` to match the canonical
  `.validate_unit_scale()` error message ("must be a positive numeric vector or NULL"
  with a `v` fix-it bullet), replacing the old duplicate message ("must be a numeric
  vector or NULL", no `v` bullet).
- `R/calibrate_to_estimate.R` had no duplicate — no change needed there.
- `devtools::document()` produced no NAMESPACE or man page changes.

## Task checklist

- [x] Remove duplicate `.validate_unit_scale()` from `R/calibrate_to_survey.R`
- [x] Confirm `R/calibrate_to_estimate.R` has no duplicate (it does not)
- [x] Confirm canonical `R/calibrate-utils.R` has NULL guard (it does, line 430-432)
- [x] Run `devtools::document()` — no NAMESPACE drift
- [x] Update snapshots to match canonical message
- [x] Run `devtools::test(filter = "sample-calibration")` — FAIL 0 | PASS 132
- [x] Run full `devtools::test()` — zero `unit_scale`-related failures remain

## CRAN compliance checklist

1. TRUE/FALSE used throughout — N/A (no new booleans)
2. `::` used for external calls — confirmed, no changes to call sites
3. No bare `print()`/`cat()` — N/A
4. `seed = NULL` on random functions — N/A
5. `on.exit()` restoring `par()`/`options()` — N/A
6. `tempdir()` with cleanup — N/A
7. `<=2` cores in examples/tests — N/A
8. `devtools::document()` run — yes, no changes
9. `requireNamespace()` not `installed.packages()` — N/A
10. All `cli_abort()`/`cli_warn()` have `class=` — confirmed, no new calls added

## HOLDs

None.
