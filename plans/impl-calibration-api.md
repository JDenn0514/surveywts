# Implementation Plan — calibration-api

**Status**: DRAFT
**Spec**: `plans/spec-calibration-api.md` (SPEC_REVIEWED)
**Test-spec**: `plans/test-spec-calibration-api.md`
**Target version**: 0.6.0.9000

---

## Overview

This plan delivers the calibration API redesign specified in `spec-calibration-api.md`.
Three existing calibration functions (`calibrate()`, `rake()`, `poststratify()`) are
deleted and replaced by `calibrate_greg()`, `calibrate_rake()`, `calibrate_poststrat()`,
and a new thin dispatcher `calibrate()`. The `targets` argument is harmonized across
all three substantive functions, and error class names are aligned with the new argument
name. Work is split across two PRs so each can be reviewed atomically.

---

## PR Map

- [ ] PR 1: `feature/calibration-api-pr1` — calibrate_greg + calibrate_rake + shared utils
- [ ] PR 2: `feature/calibration-api-pr2` — calibrate_poststrat + calibrate dispatcher + cleanup

---

## PR 1: calibrate_greg + calibrate_rake + shared utils

**Branch:** `feature/calibration-api-pr1`
**Depends on:** none

### What this PR does

Replaces old `calibrate()` and `rake()` with `calibrate_greg()` and `calibrate_rake()`.
Extracts `.parse_margins()` from `rake.R` into the new `R/calibrate-utils.R`.
After this PR: both margin-based calibration functions are exported; old `calibrate()`
and `rake()` are gone; the new `calibrate()` dispatcher does not yet exist (comes in PR 2).

### Key API changes vs old functions

| Old | New |
|-----|-----|
| `calibrate(data, variables, population, ..., method = "linear")` | `calibrate_greg(data, targets, ..., model = "linear")` |
| `rake(data, margins, ..., method = "anesrake")` | `calibrate_rake(data, targets, ..., algorithm = "anesrake")` |
| `surveywts_error_population_variable_not_found` | `surveywts_error_targets_variable_not_found` |
| `surveywts_error_margins_variable_not_found` | `surveywts_error_targets_variable_not_found` |
| `operation = "calibration"` in history | `operation = "calibrate_greg"` |
| `operation = "raking"` in history | `operation = "calibrate_rake"` |
| No warning for unknown `control` keys in `calibrate()` | `surveywts_warning_control_param_ignored` per unknown key in `calibrate_greg()` |

### Files (in TDD order — tests first)

1. **`plans/error-messages.md`** — Before writing any R code:
   - In "Thrown by" column: rename `calibrate()` → `calibrate_greg()` in the
     `calibrate()` function section
   - Rename class `surveywts_error_population_variable_not_found` →
     `surveywts_error_targets_variable_not_found` throughout
   - In "Thrown by" column: rename `rake()` → `calibrate_rake()` in the
     `rake()` function section
   - Rename class `surveywts_error_margins_variable_not_found` →
     `surveywts_error_targets_variable_not_found` throughout
   - Add `surveywts_warning_control_param_ignored` to `calibrate_greg()` section
     (new; "Thrown by" = `calibrate_greg()`; already exists in "Thrown by: `rake()`"
     row — add a second row or expand "Thrown by" to include both)
   - Note: `surveywts_warning_negative_calibrated_weights` "Thrown by" stays
     `calibrate()` for now — it will be updated to `calibrate_greg()` in the
     same PR when the new function is wired up. Update it here as a first step.

2. **`tests/testthat/test-02-calibrate.R`** — Full rewrite (TDD red phase):
   - Delete all existing tests; delete `_snaps/02-calibrate.md`
   - Write all `calibrate_greg()` test blocks from `test-spec-calibration-api.md`
     §`calibrate_greg()`: happy path, numerical oracle, error paths (dual pattern),
     warning paths, edge cases, history field
   - Write the deleted-function regression guard block
   - Tests reference `calibrate_greg()`; function doesn't exist yet → all red

3. **`tests/testthat/test-03-rake.R`** — Full rewrite (TDD red phase):
   - Delete all existing tests; delete `_snaps/03-rake.md`
   - Write all `calibrate_rake()` test blocks from `test-spec-calibration-api.md`
     §`calibrate_rake()`: happy path, numerical oracle, error paths (dual pattern),
     warning paths, message paths, edge cases, history field
   - Write the deleted-function regression guard block (old `rake()` / `margins` arg gone)
   - Tests reference `calibrate_rake()`; function doesn't exist yet → all red

4. **`R/calibrate-utils.R`** — NEW file, calibration-family shared utils:
   - Move `.parse_margins()` verbatim from `R/rake.R`; update all `{.fn rake}`
     references in error messages to `{.fn calibrate_rake}` and
     `{.fn calibrate_greg}` as appropriate
   - No exports; internal only

5. **`R/calibrate_greg.R`** — NEW file, `calibrate_greg()` exported function:
   - Rename old `calibrate()` to `calibrate_greg()`; rename arg `variables` +
     `population` → single `targets` arg; rename arg `method` → `model`
   - `targets` names now define which columns to calibrate on (replaces tidy-select
     `variables`); call `.parse_margins()` from `calibrate-utils.R` for Format B
   - Replace `surveywts_error_population_variable_not_found` →
     `surveywts_error_targets_variable_not_found` in the variable-not-found error
   - Add control-key warning: for keys not in `c("maxit", "epsilon")`, emit
     `surveywts_warning_control_param_ignored` per key after `utils::modifyList()`
   - Update `operation = "calibration"` → `operation = "calibrate_greg"` in
     history entry; rename `population` → `targets` in history `parameters` field
   - Update `@param` blocks for `targets`, `model`; add full `@references` per
     spec §IX; keep `@family calibration`; run `devtools::document()` after

6. **`R/calibrate_rake.R`** — NEW file, `calibrate_rake()` + anesrake helpers:
   - Move all content from `R/rake.R` into this file; rename function to
     `calibrate_rake()`; rename arg `margins` → `targets`
   - Remove `.parse_margins()` (now in `calibrate-utils.R`); update call sites
     to still call `.parse_margins()` (available from `calibrate-utils.R` since
     all R/ files are sourced)
   - Replace `surveywts_error_margins_variable_not_found` →
     `surveywts_error_targets_variable_not_found` in the variable-not-found error
   - Update `operation = "raking"` → `operation = "calibrate_rake"` in history;
     rename `margins` → `targets` in history `parameters` field
   - Update `@param` blocks; add full `@references` per spec §IX; keep
     `@family calibration`

7. **DELETE `R/calibrate.R`** — old file containing old `calibrate()` removed

8. **DELETE `R/rake.R`** — old file containing old `rake()` and `.parse_margins()` removed

9. **`NAMESPACE` + `man/`** — run `devtools::document()`:
   - Old `calibrate.Rd` and `rake.Rd` deleted; new `calibrate_greg.Rd` and
     `calibrate_rake.Rd` generated; NAMESPACE updated

10. **`changelog/calibration/feature-calibration-api-pr1.md`** — created last,
    before opening PR

### Acceptance criteria

- [ ] All new `test-02-calibrate.R` and `test-03-rake.R` tests confirmed failing
      (red) before `R/calibrate_greg.R` and `R/calibrate_rake.R` were created
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync
- [ ] `calibrate_greg()` and `calibrate_rake()` exported in `NAMESPACE`
- [ ] Old `calibrate()` and `rake()` absent from `NAMESPACE` and `R/`
- [ ] `test_invariants(obj)` passes as first assertion in every constructor
      `test_that()` block in test-02 and test-03
- [ ] All error paths in test-02 and test-03 use dual pattern (class + snapshot)
- [ ] History `operation` fields: `"calibrate_greg"` and `"calibrate_rake"`
      (verified by history field `test_that()` blocks)
- [ ] `plans/error-messages.md` reflects new function names in "Thrown by" column;
      `surveywts_error_targets_variable_not_found` replaces both old names
- [ ] `surveywts_warning_control_param_ignored` fires for unrecognized `control`
      keys in `calibrate_greg()` (test in warning paths)
- [ ] `surveywts_warning_control_param_ignored` fires for `control = list(pval = 0.01)`
      with `algorithm = "survey"` in `calibrate_rake()` (test in warning paths)
- [ ] `surveywts_warning_control_param_ignored` fires for `control = list(epsilon = 1e-9)`
      with `algorithm = "anesrake"` in `calibrate_rake()` (test in warning paths)
- [ ] `surveywts_message_already_calibrated` fires when data already matches targets
      in `calibrate_rake()` with `algorithm = "anesrake"` (test in message paths)
- [ ] `calibrate_greg()` oracle: weights match `survey` package GREG calibration
      within 1e-8 (skipped if `survey` not installed; `skip_if_not_installed` inside
      the block)
- [ ] `calibrate_rake()` oracle: `algorithm = "survey"` weights match `survey::rake`
      within 1e-8 (skipped if `survey` not installed; `skip_if_not_installed` inside
      the block)
- [ ] Test coverage ≥ 95% overall (verify with `covr::package_coverage()`)

### Implementation notes

**`.parse_margins()` extraction:** The function exists in `rake.R` as a private
helper. When creating `calibrate-utils.R`, copy it verbatim. When creating
`calibrate_rake.R`, do NOT duplicate it — call the version from `calibrate-utils.R`
(all R/ files are sourced together, so no explicit import needed). Delete it from
`rake.R` as part of deleting `rake.R` entirely.

**`targets` replaces `variables` + `population` in `calibrate_greg()`:** The old
function resolved variable names via `tidyselect::eval_select()`. The new function
derives variable names from `names(targets)` after Format B conversion. The
`tidyselect::eval_select()` call is removed; `variable_names <- names(targets_a)`
where `targets_a` is the Format A list returned by `.parse_margins(targets)`.

**`model` vs `method` rename:** Old `calibrate()` used `method = c("linear", "logit")`.
New `calibrate_greg()` uses `model = c("linear", "logit")`. The internal engine call
is unchanged; only the argument name changes.

**`algorithm` vs `method` rename in `calibrate_rake()`:** Old `rake()` used
`method = c("anesrake", "survey")`. New `calibrate_rake()` uses
`algorithm = c("anesrake", "survey")`. Same internal logic; argument name only.

**Control key validation in `calibrate_greg()`:** After `utils::modifyList()` resolves
control, check `setdiff(names(control), c("maxit", "epsilon"))`. For each unknown key,
emit `surveywts_warning_control_param_ignored`. Drop unknown keys before passing to
the engine.

**Error message text for `surveywts_error_targets_variable_not_found`:** Use the
same structure as the current `rake()` error for `surveywts_error_margins_variable_not_found`,
but reference `{.arg targets}` instead of `{.arg margins}`.

**Snapshot regeneration:** Deleting old test files and writing new ones means the
old snapshots are stale. Delete `_snaps/02-calibrate.md` and `_snaps/03-rake.md`
before writing new tests. Run `devtools::test()` once after implementing to generate
fresh snapshots; review and commit them.

**Old `calibrate.R` deletion:** When deleting the old file, `NAMESPACE` still lists
`export(calibrate)` until `devtools::document()` is run. Run `devtools::document()`
after deleting the file (step 9 above). CI will fail if NAMESPACE is out of sync.

---

## PR 2: calibrate_poststrat + calibrate dispatcher + cleanup

**Branch:** `feature/calibration-api-pr2`
**Depends on:** PR 1

### What this PR does

Adds `calibrate_poststrat()` and the new `calibrate()` thin dispatcher. Deletes
`poststratify.R`. After this PR: all four functions are exported; all three old
functions (`calibrate`, `rake`, `poststratify`) are fully replaced; the spec is
fully implemented.

### Key API changes vs old function

| Old | New |
|-----|-----|
| `poststratify(data, strata, population, ..., type)` | `calibrate_poststrat(data, targets, ..., type, reference_design)` |
| `strata` (tidy-select) + `population` (data frame with strata cols + target) | Single `targets` data frame; strata vars identified from `names(targets)` excluding `"target"` |
| `operation = "poststratify"` in history | `operation = "calibrate_poststrat"` |
| `calibrate()` = GREG-only (spec §III relationship) | `calibrate()` = thin dispatcher to greg/rake/poststrat |
| No `reference_design` in `poststratify()` | `reference_design` added |

### Files (in TDD order — tests first)

1. **`plans/error-messages.md`** — Before writing any R code:
   - Update "Thrown by" for `poststratify()` section → `calibrate_poststrat()`
   - Add `surveywts_error_no_strata_variables` row (new error class for
     `targets` with zero non-`"target"` columns)
   - Add `surveywts_error_targets_variable_not_found` row to `calibrate_poststrat()`
     section (same class as greg/rake; pre-join column-not-found check)
   - Add `surveywts_error_reference_design_not_taylor` row to `calibrate_poststrat()`
     section (Thrown by: `calibrate_poststrat()`; trigger: `reference_design` is
     non-NULL and not a `survey_taylor` object — per spec §V)
   - Add `surveywts_error_margins_format_invalid` row to `calibrate_poststrat()`
     section (Thrown by: `calibrate_poststrat()`; trigger: `targets` is not a
     `data.frame`, e.g. a named list or scalar — per spec §V)

2. **`tests/testthat/test-04-poststratify.R`** — Full rewrite (TDD red phase):
   - Delete all existing tests; delete `_snaps/04-poststratify.md`
   - Write all `calibrate_poststrat()` test blocks from `test-spec-calibration-api.md`
     §`calibrate_poststrat()`: happy path (including `reference_design` non-NULL
     and `survey_taylor` input), numerical oracle, error paths (dual pattern),
     edge cases, history field
   - Write deleted-function regression guard (old `poststratify()` / `strata` +
     `population` args gone)
   - Tests reference `calibrate_poststrat()`; function doesn't exist yet → all red

3. **`tests/testthat/test-02-calibrate.R`** — Add dispatcher section:
   - Append `calibrate()` dispatcher test blocks from test-spec §`calibrate()`:
     happy path (method = "greg", "rake", "poststrat", default method), error
     paths (invalid method, unknown `...`)
   - The `test_invariants(obj)` check applies to dispatcher results when the
     dispatched function returns a `weighted_df` or `survey_nonprob`

4. **`R/calibrate_poststrat.R`** — NEW file, `calibrate_poststrat()`:
   - Rename `poststratify()` to `calibrate_poststrat()`; replace `strata`
     (tidy-select) + `population` (data frame) with single `targets` data frame;
     derive strata_names from `names(targets)` excluding `"target"`
   - Add pre-function checks in order: (a) `targets` is a data frame
     (`surveywts_error_margins_format_invalid` if not); (b) zero non-`"target"`
     columns (`surveywts_error_no_strata_variables`); (c) each non-`"target"`
     column name exists in `data` (`surveywts_error_targets_variable_not_found`)
   - Add `reference_design` parameter (same validation as calibrate_greg)
   - Migrate `.validate_population_cells()` verbatim from `poststratify.R` into
     this file; update `{.fn poststratify}` references → `{.fn calibrate_poststrat}`
   - Update `operation = "poststratify"` → `operation = "calibrate_poststrat"`
     in history; `population` → `targets` in history `parameters`; add
     `variables` (derived strata_names), `targets_from_reference`, `reference_design`
   - Add full `@references` per spec §IX; `@family calibration`

5. **`R/calibrate.R`** — NEW file, thin dispatcher `calibrate()`:
   - `rlang::arg_match(method)` to validate `method = c("greg", "rake", "poststrat")`
   - Capture `weights` with `rlang::enquo(weights)`
   - `switch(method, greg = calibrate_greg(...), rake = calibrate_rake(...), poststrat = calibrate_poststrat(...))`
   - Each branch: `calibrate_greg(data, targets = targets, weights = !!weights_quo, wt_name = wt_name, type = type, reference_design = reference_design, ...)`
   - No validation beyond method matching; all errors propagate from dispatched function
   - `@family calibration`; no `@references` on the dispatcher

6. **DELETE `R/poststratify.R`** — old file removed

7. **`NAMESPACE` + `man/`** — run `devtools::document()`:
   - Old `poststratify.Rd` deleted; new `calibrate_poststrat.Rd`, `calibrate.Rd`
     (updated dispatcher), `calibrate-utils.Rd` (not generated — no export)
     generated; NAMESPACE updated

8. **`.claude/rules/surveywts-conventions.md`** — update file mapping table:
   - Replace `calibrate.R → calibrate()` (old entry) with updated entries for
     all new files; add rows for `calibrate.R` (dispatcher), `calibrate_greg.R`,
     `calibrate_rake.R`, `calibrate_poststrat.R`, `calibrate-utils.R`; remove
     rows for `rake.R`, `poststratify.R`
   - Update `@family calibration` row in §2 to list the four new function names

9. **`changelog/calibration/feature-calibration-api-pr2.md`** — created last,
    before opening PR

### Acceptance criteria

- [ ] All new `test-04-poststratify.R` tests and `test-02-calibrate.R` dispatcher
      section confirmed failing (red) before implementation
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; `NAMESPACE` and `man/` in sync
- [ ] `calibrate_poststrat()` and `calibrate()` exported in `NAMESPACE`
- [ ] Old `poststratify()` absent from `NAMESPACE` and `R/`
- [ ] All four new functions carry `@family calibration`
- [ ] All three substantive functions carry `@references` per spec §IX
- [ ] `calibrate()` dispatcher passes all four happy-path scenarios (greg, rake,
      poststrat, default = greg)
- [ ] NSE `weights` forwarded correctly: `calibrate(df, targets = pop, weights = w)`
      produces same result as `calibrate_greg(df, targets = pop, weights = w)`
- [ ] History `operation` = `"calibrate_poststrat"` (verified by history block)
- [ ] `surveywts_error_no_strata_variables` fires for `targets = data.frame(target = 1)`
- [ ] `surveywts_error_targets_variable_not_found` fires for a non-`"target"` column
      name in `targets` that is absent from `data` (pre-join check)
- [ ] `plans/error-messages.md` fully updated: calibrate_poststrat section,
      `surveywts_error_no_strata_variables` added
- [ ] Test coverage ≥ 95% overall (verify with `covr::package_coverage()`)
- [ ] Quality gates from spec §X all pass

### Implementation notes

**`targets` format in `calibrate_poststrat()`:** Unlike greg and rake, `targets` is
always a data frame (no Format A/B dual-format). The strata variable names are
`setdiff(names(targets), "target")`. Check `length(strata_names) == 0L` before any
other validation (triggers `surveywts_error_no_strata_variables`).

**Pre-join column-not-found check:** After deriving `strata_names`, check each name
against `names(plain_df)`. Emit `surveywts_error_targets_variable_not_found` for
the first missing column. This check runs before `.validate_population_cells()`.

**`reference_design` in `calibrate_poststrat()`:** Use `.validate_reference_design()`
from `utils.R` (same helper as greg and rake). Store in history `parameters` as
`targets_from_reference = !is.null(reference_design)` and `reference_design = reference_design`.

**NSE forwarding in the dispatcher:** The critical pattern is:
```r
calibrate <- function(data, targets, weights = NULL, ..., method = c("greg", ..)) {
  method <- rlang::arg_match(method)
  weights_quo <- rlang::enquo(weights)
  switch(method,
    greg = calibrate_greg(data, targets = targets,
                          weights = !!weights_quo, ...),
    ...
  )
}
```
Without `!!weights_quo`, the dispatched function receives the symbol `weights`
rather than the user's bare column reference, which breaks tidy-select lookup.

**History parameters field for calibrate_poststrat():** Store:
`variables` (character vector = `strata_names`), `targets` (the input data frame),
`type`, `targets_from_reference` (logical), `reference_design`.

**Snapshot regeneration:** Same pattern as PR 1. Delete `_snaps/04-poststratify.md`
before writing new tests. Run `devtools::test()` once after implementing to generate
fresh snapshots; review and commit.
