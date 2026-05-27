# Implementation Plan: NPS Bootstrap — `create_bootstrap_weights()`

**Version:** 1.0
**Date:** 2026-05-27
**Status:** COMPLETE
**Spec:** `plans/spec-nps-bootstrap.md` v1.2
**Test spec:** `plans/test-spec-nps-bootstrap.md` v1.0

---

## Overview

This plan delivers `type = "quasi-randomization"` and a `type = "hybrid"` error
stub for `create_bootstrap_weights()`, plus the associated `mse` API migration
from `logical(1)` to `character(1)` and the `replicates = NULL` default change.
Two PRs: PR 1 lays infrastructure (error classes + test helpers); PR 2
implements the full feature in TDD order. Both `R/replicate-weights.R` and
`R/methods-print.R` change in PR 2 only.

---

## PR Map

- [x] PR 1: `feature/nps-bootstrap-infra` — Error classes, warning classes, and NPS test helper fixtures
- [x] PR 2: `feature/nps-bootstrap-impl` — Full NPS bootstrap implementation in `create_bootstrap_weights()`

---

## PR 1: Error classes and test helpers

**Branch:** `feature/nps-bootstrap-infra`
**Depends on:** none

**Files (in order):**
- `plans/error-messages.md` — add 10 new error classes and 3 new warning classes before any R code is written
- `tests/testthat/helper-test-data.R` — add `make_nps_ref()`, `make_nps_level_a()`, `make_nps_level_b()` helpers
- `tests/testthat/test-08-nps-bootstrap.R` — smoke-test block only (3 assertions); full test suite added in PR 2

**Changes to `plans/error-messages.md`:**

Add a new subsection `### NPS Bootstrap` under `### Replicate Weight Functions`:

```
### NPS Bootstrap — `create_bootstrap_weights()` NPS types

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_error_qr_bootstrap_requires_nonprob` | `create_bootstrap_weights()` | `type = "quasi-randomization"` with non-`survey_nonprob` input |
| `surveywts_error_hybrid_bootstrap_requires_nonprob` | `create_bootstrap_weights()` | `type = "hybrid"` with non-`survey_nonprob` input |
| `surveywts_error_qr_bootstrap_no_ipw_history` | `.quasi_randomization_bootstrap()` | No `operation = "ipw"` entry in `@metadata@weighting_history` |
| `surveywts_error_qr_bootstrap_no_reference` | `.quasi_randomization_bootstrap()` | `reference_design = NULL` in ipw history AND `reference_sample` not provided |
| `surveywts_error_hybrid_bootstrap_not_implemented` | `create_bootstrap_weights()` | `type = "hybrid"` (any input) |
| `surveywts_error_reference_sample_class` | `create_bootstrap_weights()` | `reference_sample` is non-`NULL` and not `survey_taylor` (includes `survey_replicate`) |
| `surveywts_error_chrostowski_prob_sample` | `create_bootstrap_weights()` | `mse = "chrostowski"` with a probability-sample type |
| `surveywts_error_bootstrap_all_draws_failed` | `.quasi_randomization_bootstrap()` | All B draws failed; 0 successful draws |
| `surveywts_error_mse_not_character` | `create_bootstrap_weights()` | `mse` is `logical` (legacy boolean API) |
| `surveywts_error_reference_bootstrap_failed` | `.quasi_randomization_bootstrap()` (Level B) | `svrep::as_bootstrap_design()` fails on the reference design |

Warnings:

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveywts_warning_reference_sample_ignored` | `create_bootstrap_weights()` | `reference_sample` non-`NULL` and `type` is a probability-sample type |
| `surveywts_warning_bootstrap_draws_failed` | `.quasi_randomization_bootstrap()` | More than 10% of draws failed |
| `surveywts_warning_repweights_overwritten` | `create_bootstrap_weights()` | `@variables$repweights` already populated (second call overwrites) |
```

**Changes to `tests/testthat/helper-test-data.R`:**

Append three new helper functions after the existing `make_surveywts_data()`:

```r
# NPS bootstrap helpers -------------------------------------------------------

make_nps_ref <- function(seed = 42) {
  ref_df <- make_surveywts_data(n = 200, seed = seed)
  surveycore::as_survey(ref_df, weights = base_weight)
}

# Level A: margins are fixed population targets, NOT derived from ref design.
# targets_from_reference = FALSE in the rake history entry.
make_nps_level_a <- function(seed = 1, n = 500) {
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ref    <- make_nps_ref(seed = seed + 100)
  ipw_result <- ipw(
    data      = nps_df,
    reference = ref,
    selection = ~age_group + sex
  )
  rake(
    ipw_result,
    margins = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex       = c("M" = 0.49, "F" = 0.51)
    ),
    type = "prop"
    # No reference_design= argument → targets_from_reference = FALSE
  )
}

# Level B: calibration margins derived from the reference design.
# targets_from_reference = TRUE in the rake history entry.
make_nps_level_b <- function(seed = 2, n = 500) {
  ref <- make_nps_ref(seed = seed + 100)
  nps_df <- make_surveywts_data(n = n, seed = seed)
  ipw_result <- ipw(
    data      = nps_df,
    reference = ref,
    selection = ~age_group + sex
  )
  rake(
    ipw_result,
    margins = list(
      age_group = c("18-34" = 0.35, "35-54" = 0.40, "55+" = 0.25),
      sex       = c("M" = 0.49, "F" = 0.51)
    ),
    type             = "prop",
    reference_design = ref  # → targets_from_reference = TRUE
  )
}
```

**Changes to `tests/testthat/test-08-nps-bootstrap.R` (PR 1 stub):**

Create the file with a single smoke-test block:

```r
# test-08-nps-bootstrap.R
# PR 1 stub: smoke tests for NPS bootstrap helper functions.
# Full test suite is added in PR 2.

test_that("NPS bootstrap helper functions return survey_nonprob with ipw history", {
  ref   <- make_nps_ref(seed = 42)
  lev_a <- make_nps_level_a(seed = 1)
  lev_b <- make_nps_level_b(seed = 2)

  for (obj in list(ref, lev_a, lev_b)) {
    expect_true(!is.null(obj))
    expect_true(S7::S7_inherits(obj, surveywts:::survey_nonprob))
  }

  for (obj in list(lev_a, lev_b)) {
    ops <- vapply(obj@metadata@weighting_history, `[[`, character(1), "operation")
    expect_true("ipw" %in% ops)
  }
})
```

**Acceptance criteria:**
- [ ] Smoke test passes (`devtools::test(filter = "08-nps")`) — all three helpers return non-NULL `survey_nonprob` with an `ipw` history entry
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync (no changes expected)
- [ ] `plans/error-messages.md` has all 13 new classes (10 errors + 3 warnings) in new subsection
- [ ] `helper-test-data.R` has `make_nps_ref()`, `make_nps_level_a()`, `make_nps_level_b()` that each return a valid `survey_nonprob`
- [ ] `test_invariants()` passes on objects returned by each helper
- [ ] Existing tests still pass (`devtools::test()`)

**Notes:**
- `make_nps_level_a()` and `make_nps_level_b()` both call `ipw()` and `rake()`. Both these
  functions already exist. Verify manually that the helpers produce a `survey_nonprob` with
  a non-empty `@metadata@weighting_history` containing an `ipw` entry.
- The `rake()` call in `make_nps_level_b()` passes `reference_design = ref`, which sets
  `targets_from_reference = TRUE` in the rake history entry — this is what triggers Level B
  detection in the bootstrap.
- The Level A helper uses hardcoded `type = "prop"` margins (not from the reference design)
  so `targets_from_reference = FALSE`.

---

## PR 2: NPS bootstrap implementation

**Branch:** `feature/nps-bootstrap-impl`
**Depends on:** PR 1

**Files (in TDD order — tests first):**
- `plans/error-messages.md` — no changes (done in PR 1)
- `tests/testthat/test-08-nps-bootstrap.R` — expand to full test suite (all blocks from `test-spec-nps-bootstrap.md`)
- `tests/testthat/_snaps/08-nps-bootstrap.md` — snapshot file; approved and committed after `testthat::snapshot_review()`
- `tests/testthat/test-replicate-weights.R` — one-line fix: change `mse = FALSE` to `mse = "uncentered"` at the `create_bootstrap_weights()` call (line ~162); the `expect_false(history[[1L]]$parameters$mse)` assertion stays correct because `"uncentered" == "mse"` evaluates to `FALSE`
- `R/replicate-weights.R` — full changes: signature update, new private helper, type dispatch
- `R/methods-print.R` — extend `survey_nonprob` print for `@variables$repweights`
- `man/create_bootstrap_weights.Rd` — auto-generated by `devtools::document()`
- `changelog/replicate/feature-nps-bootstrap.md` — created last, before opening PR

**TDD sub-steps (follow strictly):**

1. **RED**: Write all blocks from `test-spec-nps-bootstrap.md` into `test-08-nps-bootstrap.R`
   **except Block 7**, which is superseded by the corrected design in TDD step 4 below.
   For Block 7, write the version from this plan's step 4 (compare `make_nps_level_a()` vs.
   `make_nps_level_b()` directly — do NOT use the `reference_sample` override approach).
   Run `devtools::test(filter = "08-nps")` — every test must fail before implementation begins.
   If any test passes accidentally, investigate before proceeding.

2. **GREEN for errors and warnings (E1–E11, W1–W3)**:
   - Change `create_bootstrap_weights()` signature (§III).
   - Add `mse` boolean pre-check (§III.A).
   - Add `rlang::arg_match()` with new types.
   - Add `replicates = NULL` internal resolution.
   - Add type dispatch: NPS path vs. prob-sample path.
   - Add `surveywts_error_chrostowski_prob_sample` check in prob-sample branch.
   - Add `mse_logical` conversion before `.convert_and_call()`.
   - Add `.validate_reference_sample()` private helper.
   - Add `surveywts_warning_reference_sample_ignored` in prob-sample branch.
   - Add `surveywts_error_qr_bootstrap_requires_nonprob` / `surveywts_error_hybrid_bootstrap_requires_nonprob` in NPS branch.
   - Add `surveywts_error_hybrid_bootstrap_not_implemented` stub.
   - Tests E1–E11, W1 should now pass.

3. **GREEN for Level A happy path (Blocks 1, 3, 4, 5, EC3, EC4, EC5, H1)**:
   - Implement `.quasi_randomization_bootstrap()` private helper (Level A path).
   - Prerequisites check (§IV): ipw history entry, reference design resolution.
   - Level A/B detection rule (`use_level_b` flag).
   - Level A loop: SRSWR resample → clean `S_A_b` (drop weight, revert `"(Missing)"`) → re-run `ipw()` → re-run calibration (if in history) → extract replicate weight vector → handle draw failures.
   - Post-loop: warn if >10% draws failed; error if all draws failed.
   - Assemble output: add `repwt_*` columns to `@data`, set `@variables$repweights`, append history entry.
   - Second-call overwrite logic (`surveywts_warning_repweights_overwritten`).
   - Blocks 1, 3, 4, 5, EC3, EC4, EC5, H1 should pass.

4. **GREEN for Level B happy path (Blocks 2, 7)**:
   - Add Level B branch to `.quasi_randomization_bootstrap()`.
   - Pre-loop: `surveycore::as_svydesign(ref_design)` → `svrep::as_bootstrap_design(ref_svydesign, replicates = B)` wrapped in `tryCatch()` (→ `surveywts_error_reference_bootstrap_failed` on failure).
   - Per-draw: extract b-th replicate weights from `ref_boot`, construct resampled reference `survey_taylor`, pass to `ipw()`.
   - Level B: re-estimate calibration targets from resampled reference before re-running `rake()` / `calibrate()`.
   - Blocks 2 and 7 should pass. Block 7 (differential test) is the key correctness check:
     compare `make_nps_level_a()` output (rake without `reference_design`) vs.
     `make_nps_level_b()` output (rake with `reference_design`) at the same seed and assert
     that repwt columns differ. Do NOT use `reference_sample` to "force Level A" —
     `reference_sample` does not affect Level A/B detection.

5. **GREEN for print extension (Blocks 8–9)**:
   - Extend `S7::method(print, surveycore::survey_nonprob)` in `R/methods-print.R`:
     after the weights summary line, if `!is.null(x@variables$repweights)`, append:
     `"Bootstrap replicates: {B} ({type}, level {level})"` where B, type, level
     are read from the last `"bootstrap_weights"` entry in `@metadata@weighting_history`.
   - Blocks 8 and 9 (snapshot tests) should pass. Run `testthat::snapshot_review()` to
     approve snapshot content.

6. **GREEN for edge cases and numerical test (EC1, EC2, W2, N1)**:
   - EC1 (very small NPS): should work with the existing implementation if draw failures are handled.
   - EC2 (all draws fail): the 3-row degenerate NPS; confirm `surveywts_error_bootstrap_all_draws_failed` fires.
   - W2 (>10% draw failures): a constrained NPS; confirm `surveywts_warning_bootstrap_draws_failed` fires.
   - N1 (numerical SE check): run with `skip_if_slow()` or a wide tolerance check.

7. **Final checks**: `devtools::document()`, `devtools::test()`, `devtools::check()`.

**Detailed implementation notes:**

**`create_bootstrap_weights()` new signature:**
```r
create_bootstrap_weights <- function(
  data,
  replicates = NULL,
  ...,
  type = c(
    "Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille",
    "Preston", "Canty-Davison",
    "quasi-randomization", "hybrid"
  ),
  reference_sample = NULL,
  mse = c("mse", "chrostowski", "uncentered"),
  seed = NULL
)
```

**Validation order in `create_bootstrap_weights()` body:**
1. `.validate_replicate_input(data)` (existing — catches data.frame, weighted_df, survey_replicate)
2. `if (is.logical(mse))` → `surveywts_error_mse_not_character`
3. `type <- rlang::arg_match(type)`
4. `mse <- rlang::arg_match(mse)` (use `c("mse", "chrostowski", "uncentered")`)
5. `if (is.null(replicates)) replicates <- if (type %in% c("quasi-randomization", "hybrid")) 200L else 500L`
6. `replicates <- .validate_replicates_arg(replicates)`
7. Dispatch: `if (type %in% c("quasi-randomization", "hybrid"))` else prob-sample path

**In NPS dispatch branch:**
```r
if (!S7::S7_inherits(data, surveycore::survey_nonprob)) {
  # error: surveywts_error_qr_bootstrap_requires_nonprob or hybrid variant
}
if (!is.null(reference_sample)) {
  .validate_reference_sample(reference_sample)
}
if (type == "quasi-randomization") {
  .quasi_randomization_bootstrap(data, replicates, reference_sample, mse, seed)
} else {
  # hybrid stub error
}
```

**In prob-sample dispatch branch:**
```r
if (mse == "chrostowski") {
  cli::cli_abort(...)  # surveywts_error_chrostowski_prob_sample
}
if (!is.null(reference_sample)) {
  cli::cli_warn(...)  # surveywts_warning_reference_sample_ignored
}
mse_logical <- mse == "mse"
.convert_and_call(..., mse = mse_logical)
```

**`.validate_reference_sample()` private helper** (define at top of `replicate-weights.R`):
Checks that `reference_sample` is a `survey_taylor` S7 object. If it is a
`survey_replicate`, include the `calibrate_to_survey` suggestion in the `"v"` bullet.
Returns `invisible(TRUE)` on success.

**`.quasi_randomization_bootstrap()` structure:**
```
Prerequisites check (§IV):
  - find ipw_entry (operation == "ipw"), else error
  - resolve ref_design: reference_sample %||% ipw_entry$reference_design, else error
  - find calib_entry (last entry with operation in c("raking", "calibration")), or NULL

Level A/B detection:
  use_level_b <- isTRUE(calib_entry$parameters$targets_from_reference)
  # isTRUE(NULL) = FALSE, so ipw-only and Level A workflows get use_level_b = FALSE.
  # Level B fires only when rake()/calibrate() was called with reference_design=,
  # which sets calib_entry$parameters$targets_from_reference = TRUE.
  # NOTE: !is.null(ipw_entry$reference_design) is NOT included — ipw() always stores
  # reference_design, so that clause overfires on every valid NPS bootstrap call.

Second-call overwrite check:
  if (!is.null(data@variables$repweights)) warn + record n for message

set.seed(seed) once if non-NULL

Level B pre-loop (if use_level_b):
  ref_svydesign <- surveycore::as_svydesign(ref_design)
  ref_boot <- tryCatch(svrep::as_bootstrap_design(ref_svydesign, replicates = B), ...)

Main loop b = 1..B (with tryCatch per draw):
  Step 1: resample S_A_b from data@data, drop weight column, revert "(Missing)" if needed
  Step 2 (Level B only): extract b-th reference replicate; build resampled ref survey_taylor
  Step 3: re-run ipw()
  Step 4 (if calib_entry): re-run rake()/calibrate() with fixed or perturbed targets
  Step 5: extract final weight vector
  Catch errors: increment failed_draws, skip draw

Post-loop:
  if (failed_draws > 0.1 * B) warn
  if (failed_draws >= B) error

Assemble output:
  Add repwt_1...repwt_B columns to data@data
  Columns are named sequentially from repwt_1 to repwt_{draws_used} — not indexed by
  original draw number (failed draws leave no gap in the column sequence).
  Set data@variables$repweights <- repwt_names
  Append bootstrap_weights history entry (§VI)
  Return modified data (survey_nonprob)
```

**In-loop calibration replay (Step 4) — explicit field list:**

When `calib_entry$operation == "raking"` (from `rake()`):
```r
calib_result_b <- rake(
  data    = ipw_result_b,
  margins = calib_entry$parameters$margins,       # Level A: fixed; Level B: perturbed per-draw
  type    = calib_entry$parameters$type,
  method  = calib_entry$parameters$method,
  cap     = calib_entry$parameters$cap,
  control = calib_entry$parameters$control
)
```

When `calib_entry$operation == "calibration"` (from `calibrate()`):
```r
calib_result_b <- calibrate(
  data       = ipw_result_b,
  variables  = calib_entry$parameters$variables,  # Level A: fixed; Level B: perturbed per-draw
  population = calib_entry$parameters$population,
  method     = calib_entry$parameters$method,
  type       = calib_entry$parameters$type,
  control    = calib_entry$parameters$control
)
```

Do NOT pass `reference_design` in the in-loop call — it is not needed for Level A draws, and
for Level B draws the perturbed targets are already computed from the resampled reference.

**Level B calibration target re-estimation:**
For each draw b, when `calib_entry` is non-NULL and `use_level_b = TRUE`:
- Extract the b-th reference replicate's weights from `ref_boot$repweights[, b]`
- For `type = "prop"` margins: compute proportions from the resampled reference rows weighted by those replicate weights
- For `type = "count"` margins: compute counts
- Pass the perturbed targets (same structure as `calib_entry$parameters$margins`) to `rake()`/`calibrate()` using the explicit field lists above

**History entry (§VI):**
```r
list(
  step       = length(data@metadata@weighting_history) + 1L,
  operation  = "bootstrap_weights",
  timestamp  = Sys.time(),
  type       = "quasi-randomization",
  replicates = B,
  draws_used = B - failed_draws,
  level      = if (use_level_b) "B" else "A",
  mse        = mse,
  seed       = seed
)
```

**Print extension (`R/methods-print.R`):**
After the weighting history block, before `invisible(x)`, add:
```r
# Bootstrap replicates line (only when repweights are present)
repwts <- x@variables$repweights
if (!is.null(repwts) && length(repwts) > 0L) {
  history <- x@metadata@weighting_history
  boot_entry <- Filter(function(e) identical(e$operation, "bootstrap_weights"), history)
  if (length(boot_entry) > 0L) {
    e <- boot_entry[[length(boot_entry)]]
    cat(sprintf(
      "# Bootstrap replicates: %d (%s, level %s)\n",
      e$draws_used, e$type, e$level
    ))
  }
}
```

**Snapshot tests:**
After implementing the print extension, run `devtools::test(filter = "08-nps")` for
the snapshot blocks (8 and 9). Review and approve with `testthat::snapshot_review()`.
Commit the `_snaps/` file in the same PR.

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] All happy-path test blocks pass (Blocks 1–10 per test-spec)
- [ ] All error-path tests pass with dual pattern (E1–E11 per test-spec)
- [ ] All warning-path tests pass (W1–W3 per test-spec)
- [ ] All edge-case tests pass (EC1–EC5 per test-spec)
- [ ] History entry structure test passes (H1 per test-spec)
- [ ] Block N1 (numerical SE check) passes (may use `skip_if_slow()`)
- [ ] Block 7 Level B differential test passes (repwt columns differ from Level A)
- [ ] Print snapshots approved and committed to `tests/testthat/_snaps/`
- [ ] `@variables$repweights` populated in all quasi-randomization outputs
- [ ] `@variables$weights` unchanged from input in all outputs
- [ ] `replicates = NULL` resolves to 200L for NPS types and 500L for prob-sample types
- [ ] `seed` produces identical replicate columns on identical calls
- [ ] `reference_sample` takes precedence over stored reference in ipw history
- [ ] `mse = TRUE` / `mse = FALSE` emits `surveywts_error_mse_not_character` with migration message
- [ ] `mse` character value correctly converted to logical before `.convert_and_call()`
- [ ] Second call emits `surveywts_warning_repweights_overwritten` and replaces columns
- [ ] `surveywts_warning_reference_sample_ignored` fires for all 5 probability-sample types
- [ ] Level B `svrep::as_bootstrap_design()` failure produces `surveywts_error_reference_bootstrap_failed`
- [ ] `create_bootstrap_weights()` roxygen includes `@details` caveat per spec §III.D
- [ ] `create_bootstrap_weights()` roxygen includes `@references` (Elliott & Valliant 2017, Wu 2022, Chrostowski et al. 2025, Kolenikov 2014)
- [ ] `@param seed` documents NPS vs. prob-sample RNG restoration difference: NPS types call `set.seed()` and do not restore caller RNG state; prob-sample types use `withr::local_seed()` and restore it (per spec §III.C)
- [ ] Test coverage ≥ 98% on new code in `R/replicate-weights.R`
- [ ] Test coverage ≥ 98% on new code in `R/methods-print.R`
- [ ] Changelog entry written

**Notes:**
- The `S_A_b` construction has three sub-steps that must happen in order: (1) SRSWR resample
  rows from `data@data`, (2) drop the weight column so `ipw()` Rule 11 doesn't fire, (3) revert
  `"(Missing)"` factor values to `NA` if `ipw_entry$missing_method == "separate"`. Steps 2 and 3
  are both required for the within-draw `ipw()` call to succeed — see spec §IV Step 1 and
  Issues 40–41 in `spec-review-nps-bootstrap.md`.
- `estimating_eq = ipw_entry$estimating_eq` and `adjust_reference = ipw_entry$adjust_reference`
  must both be replayed in the within-draw `ipw()` call — see spec §VII (Issues 42–43).
- For Level B, `set.seed(seed)` is called once immediately before `svrep::as_bootstrap_design()`.
  Do NOT call `set.seed()` again before the main loop — both pre-computation and loop draw
  sequentially from the same initialized stream.
- The `%||%` operator (null-coalesce) is in `rlang`. Use `reference_sample %||% ipw_entry$reference_design`.
- When extracting the b-th reference replicate from `ref_boot` for Level B, use
  `as.matrix(ref_boot$repweights)[, b]` to get the weight vector. Construct a minimal
  `survey_taylor` from the original `ref_design@data` with these weights substituted.
- The `calib_entry$margins` structure (from `rake()` history) stores the margin list; use it
  directly for Level A draws. For Level B, re-estimate proportions/counts from the resampled
  reference before passing to the in-loop `rake()`/`calibrate()` call.
- Existing probability-sample test file `test-replicate-weights.R` provides Block 6
  regression guard — do not touch that file; just confirm it still passes.
