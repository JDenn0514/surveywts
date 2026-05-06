# feat(utils): add shared internal helpers in R/07-utils.R

**Date**: 2026-03-04
**Branch**: feature/phase-0-utils
**Phase**: Phase 0

## Changes

- Add `R/07-utils.R` with all shared internal helpers used by 2+ source files:
  `.format_history_step()`, `.get_weight_col_name()`, `.get_weight_vec()`,
  `.validate_weights()`, `.validate_calibration_variables()`,
  `.validate_population_marginals()`, `.compute_weight_stats()`,
  `.make_history_entry()`, `.make_weighted_df()`, `.update_survey_weights()`,
  and `.calibrate_engine()` (including GREG, IPF, anesrake, and poststratify dispatch)
- Move `.format_history_step()` from `R/00-classes.R` to `R/07-utils.R`; update
  `print.weighted_df()` to delegate weight statistics to `.compute_weight_stats()`
- Rename vendored calibration files from `R/vendor/calibrate-greg.R` →
  `R/vendor-calibrate-greg.R` and `R/vendor/calibrate-ipf.R` →
  `R/vendor-calibrate-ipf.R` (flat naming, removes subdirectory)
- Fix test fixture: rename history entry parameter `by` → `by_variables` in
  `test-00-classes.R` to match the finalised history entry schema
- Mark PR 4 complete in `plans/impl-phase-0.md`
- Update `VENDORED.md` to reflect new vendor file paths

## Files Modified

- `R/07-utils.R` — new file; all shared internal helpers for calibration functions
- `R/vendor-calibrate-greg.R` — vendored GREG code (renamed from `R/vendor/calibrate-greg.R`)
- `R/vendor-calibrate-ipf.R` — vendored IPF code (renamed from `R/vendor/calibrate-ipf.R`)
- `R/vendor/calibrate-greg.R` — deleted (superseded by flat naming)
- `R/vendor/calibrate-ipf.R` — deleted (superseded by flat naming)
- `R/00-classes.R` — remove `.format_history_step()`, delegate to `.compute_weight_stats()`
- `tests/testthat/test-00-classes.R` — fix `by` → `by_variables` in nonresponse history fixtures
- `VENDORED.md` — update vendor file paths
- `plans/impl-phase-0.md` — mark PR 4 complete
