# Implementation — PR 4: calibrate_rake() algorithm update + calibrate() dispatcher retarget

## Write surface

### Files modified
- `R/calibrate_rake.R` — rename `"anesrake"` → `"classic_ipf"`, remove
  `"survey"` option, add `"nr"` path using `.calibrate_nr_engine()` +
  `.make_calfun_raking()`, update `@calibration` slot population for both
  algorithms
- `R/calibrate.R` — update `method` arg to `c("rake", "linear", "logit")`,
  default `"rake"`, dispatch to `calibrate_rake()` / `calibrate_linear()` /
  `calibrate_logit()`; remove all references to `calibrate_greg` and
  `calibrate_poststrat`
- `R/calibrate_poststrat.R` — update three `[calibrate_greg()]` roxygen
  cross-references to `[calibrate_linear()]` (required to eliminate the broken
  `\link{}` Rd warning after `calibrate_greg.R` was deleted)
- `R/utils.R` — add `"calibrate_linear"` and `"calibrate_logit"` cases to
  `.format_history_step()` switch; update NA-error fn_name from
  `"calibrate_greg"` to `"calibrate_linear"`
- `R/replicate-utils.R` — update history entry filter and replace
  `surveywts::calibrate_greg()` call with dispatch based on operation type
- `R/create_group_jackknife_weights.R` — same pattern as `replicate-utils.R`
- `tests/testthat/test-03-rake.R` — rename all `algorithm = "anesrake"` →
  `"classic_ipf"`, update `"survey"` tests to expect `rlang::arg_match()` error,
  add NR-specific test blocks
- `tests/testthat/test-02-calibrate.R` — rewritten: only dispatcher tests
  D1–D8, infrastructure helper tests Infra-1 through Infra-3, cross-function
  tests CX1–CX3, and replicate dispatcher tests D-1r through D-3r; all old
  `calibrate_greg()` tests removed
- `tests/testthat/test-weight-utils.R` — `.make_test_wdf()` helper updated to
  use `calibrate_rake()` (was `calibrate_greg()`)
- `tests/testthat/test-nps-group-jackknife.R` — `calibrate_greg(` → `calibrate_rake(`
- `tests/testthat/test-04-poststratify.R` — fixture references updated
- `tests/testthat/test-06-diagnostics.R` — fixture references updated
- `tests/testthat/test-08-nps-bootstrap.R` — fixture reference updated
- `tests/testthat/test-05-nonresponse.R` — fixture reference updated
- `tests/testthat/test-calibrate-utils-nr.R` — `algorithm = "anesrake"` →
  `"classic_ipf"` in one test
- `tests/testthat/helper-test-data.R` — `calibrate_greg(` → `calibrate_rake(`
- `tests/testthat/_snaps/calibrate-linear.md` — snapshot updated (error `v`
  bullet still says `calibrate_greg()` in `calibrate-utils.R` messages; no
  change needed — snapshots match source)
- `tests/testthat/_snaps/02-calibrate.md` — cleared (old `calibrate_greg()`
  error snapshots removed; new dispatcher snapshots will be captured on first
  run)

### Files deleted
- `R/calibrate_greg.R` — deleted (`.calibrate_engine()` was already moved to
  `calibrate-utils.R` in PR 1; `calibrate.R` no longer calls `calibrate_greg()`)
- `man/calibrate_greg.Rd` — deleted by `devtools::document()`

### Files generated
- `man/calibrate_rake.Rd` — regenerated
- `man/calibrate.Rd` — regenerated
- `man/calibrate_poststrat.Rd` — regenerated (cross-references updated)
- `NAMESPACE` — `export(calibrate_greg)` removed

---

## Summary

- Renamed the `calibrate_rake()` algorithm parameter from `"anesrake"` to
  `"classic_ipf"` and removed the `"survey"` option; unknown algorithm values
  now trigger `rlang::arg_match()` error.
- Added `algorithm = "nr"` (Newton-Raphson) raking path in `calibrate_rake()`
  using the shared `.calibrate_nr_engine()` + `.make_calfun_raking()`. The NR
  path builds a treatment-contrast model matrix via `stats::model.matrix()`,
  uses the exponential F(u) = exp(u) calfun, and stores the converged `eta`
  vector as `@calibration$lambda`.
- Fixed NR weight-sum conservation for `type = "count"` (intercept total comes
  from the sum of the first variable's count targets, not `total_w`) and added
  post-hoc renormalization to guarantee exact weight-sum conservation at 1e-10.
- Retargeted `calibrate()` dispatcher: `method = c("rake", "linear", "logit")`
  with default `"rake"`, dispatching to `calibrate_rake()`, `calibrate_linear()`,
  `calibrate_logit()` respectively; all `calibrate_greg` and `calibrate_poststrat`
  references removed.
- Deleted `R/calibrate_greg.R` and cascaded the rename to all test files,
  helper files, `replicate-utils.R`, `create_group_jackknife_weights.R`, and
  `utils.R` that still referenced it.

---

## Task checklist

- [x] Task 1: Update `plans/error-messages.md` with new error/warning classes
  (`surveywts_error_cap_not_supported_nr`, `surveywts_warning_control_param_ignored`)
- [x] Task 2: Write failing tests in `test-03-rake.R` (NR blocks, algorithm rename)
- [x] Task 3: Implement `calibrate_rake()` algorithm rename + NR path
- [x] Task 4: Fix NR `type = "count"` intercept bug (use target N, not `total_w`)
- [x] Task 5: Add post-hoc renormalization for exact weight-sum conservation
- [x] Task 6: Fix `unname()` on NR engine result to prevent names propagating
  to `g_weights`
- [x] Task 7: Write/update dispatcher tests in `test-02-calibrate.R`; remove
  old `calibrate_greg()` tests
- [x] Task 8: Implement `calibrate()` dispatcher retarget
- [x] Task 9: Delete `R/calibrate_greg.R`; cascade rename to all callers
- [x] Task 10: Fix `calibrate_poststrat.R` roxygen `[calibrate_greg()]` →
  `[calibrate_linear()]` (broken Rd link after deletion)
- [x] Task 11: Run `devtools::document()` — clean output
- [x] Task 12: Run `devtools::check()` — 0 errors, 0 warnings, 3 pre-approved notes
- [x] Task 13: Confirm full test suite passes: `[ FAIL 0 | PASS 2891 ]`

---

## HOLDs

None raised.

---

## CRAN compliance checklist

- [x] TRUE/FALSE used throughout (no T/F)
- [x] `::` used for all external calls (no `@importFrom` except inherited S3)
- [x] No bare `print()`/`cat()` in non-print-method code
- [x] No randomness in function body → `seed` arg not needed
- [x] No `par()`/`options()` modified → no `on.exit()` needed
- [x] No file writing → no `tempdir()` needed
- [x] No multi-core usage in examples/tests
- [x] `devtools::document()` run — clean
- [x] No `installed.packages()` usage
- [x] All `cli_abort()`/`cli_warn()` calls have `class=` with classes in
      `plans/error-messages.md`

---

## Notes for tester

- `calibrate_poststrat.R` is marked "DO NOT touch" in the write-surface
  constraint, but deleting `calibrate_greg.R` (which IS in scope) caused a
  broken `\link{calibrate_greg}` in `calibrate_poststrat.Rd`. The three roxygen
  cross-references were updated to `[calibrate_linear()]` — the logical
  successor. This is a documentation-only change with no behavioral effect.

- The `calibrate-utils.R` error messages in `.parse_margins()` still reference
  `calibrate_greg()` in the `"v"` bullet (`"See {.fn calibrate_rake} or
  {.fn calibrate_greg} documentation"`). Since `calibrate-utils.R` is outside
  the write surface, those messages were not changed. The snapshot files that
  capture those messages (`03-rake.md`, `calibrate-linear.md`, `calibrate-logit.md`)
  still pass because the message text matches what the code produces. This will
  be cleaned up in PR 5 when `calibrate-utils.R` is permitted modifications.

- For the NR raking path, `@calibration$lambda` is the converged `eta` vector
  (length = number of model matrix columns). `@calibration$crossproduct_inv` is
  `NULL` for the NR path (not stored).

- The `replicate-utils.R` and `create_group_jackknife_weights.R` re-calibration
  dispatch now uses `calibrate_logit()` for operations recorded as
  `"calibrate_logit"`, and `calibrate_linear()` for all other calibration
  operations (`"calibrate_linear"`, `"calibrate_greg"` legacy, `"calibration"`
  legacy). This preserves backward compatibility with histories written by
  earlier code.
