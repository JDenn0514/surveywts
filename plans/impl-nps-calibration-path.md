# Implementation Plan — nps-calibration-path

**Status**: DRAFT
**Spec**: `plans/spec-nps-calibration-path.md`
**Test-spec**: `plans/test-spec-nps-calibration-path.md`

## Overview

This plan delivers the calibration-only replicate path for NPS variance
estimation. PR 1 adds the path to `.quasi_randomization_bootstrap()` in
`replicate-utils.R`; PR 2 adds the analogous path to
`create_group_jackknife_weights.R`. Both PRs replace a hard IPW requirement
with a history-routing gate and retire the old `_no_ipw_history` error classes.
`plans/error-messages.md` is already updated.

## PR map

- [x] PR 1: `feature/nps-calib-bootstrap` — calibration-only QR bootstrap path in `.quasi_randomization_bootstrap()`
- [ ] PR 2: `feature/nps-calib-dagjk` — calibration-only DAGJK path in `create_group_jackknife_weights()`

---

## PR 1: Calibration-only QR bootstrap path

**Branch:** `feature/nps-calib-bootstrap`
**Depends on:** none

### Files (TDD order)

- `tests/testthat/test-replicate-weights.R` — add calibration-only QR bootstrap test suite
- `R/create_bootstrap_weights.R` — fix "i" bullet in `surveywts_error_qr_bootstrap_requires_nonprob`
- `R/replicate-utils.R` — rewrite `.quasi_randomization_bootstrap()` routing, add calibration-only algorithm, replace retired error class, fix warning text
- `changelog/replicate/feature-nps-calib-bootstrap.md` — created last, before opening PR

### Tasks

1. **[test]** Snapshot cleanup — delete any existing snapshot entries in
   `tests/testthat/_snaps/test-replicate-weights.txt` for the retired class
   `surveywts_error_qr_bootstrap_no_ipw_history`. Run
   `testthat::snapshot_review()` after the first full test run to accept
   updated snapshots. Also delete any snapshot for
   `surveywts_warning_bootstrap_draws_failed` (its "i" bullet text changes in
   this PR).

2. **[test]** Write failing tests — error paths. In
   `test-replicate-weights.R`, add a clearly labelled section
   `# calibration-only QR bootstrap — error paths`. Add dual `expect_error` +
   `expect_snapshot` blocks for:
   - `surveywts_error_qr_bootstrap_no_history` (triggered by `nps_no_history`)
   - `surveywts_error_reference_sample_class` (triggered by
     `reference_sample = data.frame(x = 1)` with `nps_calib_a`)
   - Snapshot assertion that `surveywts_error_qr_bootstrap_requires_nonprob`
     message does NOT contain "with IPW history" (use a `survey_taylor` input
     as the trigger).
   - `surveywts_error_qr_bootstrap_no_reference` (triggered by `nps_calib_b`
     variant with `calib_entry$parameters$reference_design` cleared to `NULL`
     and no `reference_sample` argument supplied).

3. **[test]** Write failing tests — calibration-only Level A happy path. In
   the same section, add:
   - Returns `survey_nonprob`; `@variables$repweights` has length 20;
     `test_invariants(result)` passes (`nps_calib_a`, 20 replicates, seed 1)
   - Last history entry has `operation = "bootstrap_weights"` and `level = "A"`
   - Weight conservation: `sum(repwt_1)` within 1e-6 of `sum(main_weight)`
   - Repwt column names are `repwt_1`...`repwt_20`
   - Original columns unchanged
   - Reproducibility: same seed gives identical `repwt_1`
   - `reference_sample` supplied but unused for Level A: no error

4. **[test]** Write failing tests — dispatch coverage (one block each). Add
   blocks for `calibrate_linear`, `calibrate_logit`, and `poststratify` as
   the calibration operation (all Level A). Each block: create the fixture
   inline, call `create_bootstrap_weights(replicates = 10L, seed = 1L)`,
   assert `class(result) == "survey_nonprob"` and
   `length(result@variables$repweights) == 10`. Run `devtools::test()` to
   confirm all new tests are RED.

5. **[test]** Write failing tests — calibration-only Level B and warning paths.
   - Level B: `nps_calib_b`, `replicates = 20L`, `seed = 2L`,
     `reference_sample = ref_data` → `survey_nonprob` with 20 repweights;
     `test_invariants` passes; history entry has `level = "B"`
   - Warning: `surveywts_warning_repweights_overwritten` on second call to
     `create_bootstrap_weights()` on the same `nps_calib_a`
   - Edge: all-draws-fail when calibration history entry has both
     `parameters$targets = NULL` and `parameters$margins = NULL`
     (5 replicates; error `surveywts_error_bootstrap_all_draws_failed`)

6. **[test]** Write regression tests — existing paths. Add blocks explicitly
   verifying:
   - IPW-only path (`make_nonprob_no_repweights()`): returns `survey_nonprob`
     with repweights, no error
   - Doubly-robust Level A (`make_nps_level_a()`): same assertion
   - Doubly-robust Level B (`make_nps_level_b()`): same assertion
   Confirm these are GREEN (existing behavior unchanged). This establishes a
   regression baseline.

7. **[impl]** Fix "i" bullet — `create_bootstrap_weights.R` line ~137. Change:
   ```
   "The quasi-randomization bootstrap is designed for non-probability samples
   with IPW history."
   ```
   to:
   ```
   "The quasi-randomization bootstrap is designed for non-probability samples."
   ```
   Run `devtools::test()` → the snapshot block from task 2 should turn GREEN;
   confirm other snapshot tests remain GREEN.

8. **[impl]** Implement routing logic in `.quasi_randomization_bootstrap()` —
   `replicate-utils.R`. Before the "Prerequisites check" block:
   - Find last IPW entry: `Filter(function(e) identical(e$operation, "ipw"), history)`
   - Find last calibration entry: operations in
     `c("calibrate_rake", "calibrate_linear", "calibrate_logit", "poststratify", "raking")`
   - Route:
     - IPW entry found → proceed with existing IPW path (preserve all existing code)
     - Calibration entry found, no IPW → new calibration-only branch (task 9)
     - Neither found → `cli_abort(class = "surveywts_error_qr_bootstrap_no_history")`
   Replace the existing `surveywts_error_qr_bootstrap_no_ipw_history` block
   with the new `surveywts_error_qr_bootstrap_no_history` block. Leave the
   rest of the IPW path (reference resolution, SRSWR loop) intact inside the
   `if (has_ipw_entry)` branch.

9. **[impl]** Implement calibration-only bootstrap algorithm (Level A + B) AND
   extract shared dispatch helper — `replicate-utils.R`.

   **9a — Extract `.dispatch_calibration_replay()` helper.** Add a new internal
   helper in `replicate-utils.R`:
   ```r
   .dispatch_calibration_replay <- function(data, calib_entry, ref_design, use_level_b)
   ```
   This helper owns the full calibration dispatch table and is the single
   authoritative implementation shared by PR 1 (bootstrap) and PR 2 (DAGJK):
   | operation | function | parameters forwarded |
   |---|---|---|
   | `"calibrate_rake"` / `"raking"` | `calibrate_rake()` | `targets`, `type`, `algorithm`, `cap`, `control` |
   | `"calibrate_linear"` | `calibrate_linear()` | `targets`, `type`, `bounds`, `bounds_scale`, `unit_scale`, `control` |
   | `"calibrate_logit"` | `calibrate_logit()` | `targets`, `type`, `bounds`, `bounds_scale`, `unit_scale`, `control` |
   | `"poststratify"` | `poststratify()` | `targets`, `type` |
   - For `"raking"` legacy entries: fall back to `calib_entry$parameters$margins`
     when `$targets` is NULL.
   - `poststratify` must NOT receive `algorithm`, `cap`, `control`, or `bounds` args.
   - For Level B: call `.reestimate_margins_from_reference()` before dispatch.
   - **Before coding dispatch**, verify each calibration function stores its
     parameters under `$parameters` in the weighting history entry. If a
     parameter is absent, the dispatch uses the function default. Document any
     gaps in the PR description.

   **9b — Implement calibration-only branch.** Add a `} else { # calibration-only path`
   branch after the IPW routing in task 8. This branch:
   - Detects Level A vs Level B from
     `isTRUE(calib_entry$parameters$targets_from_reference)`
   - For Level B: resolves `ref_design` from `reference_sample` arg (takes
     precedence) or `calib_entry$parameters$reference_design`; errors with
     `surveywts_error_qr_bootstrap_no_reference` if both NULL
   - For Level A: `ref_design = NULL`; `n_ref = 0L`
   - Runs `.handle_repweights_overwrite()` (same as IPW path)
   - Main loop: SRSWR resample → assign equal weight 1 per row → call
     `.dispatch_calibration_replay(data, calib_entry, ref_design, use_level_b)`.
     A draw fails if the dispatch function errors OR if any output weight is ≤ 0
     (for `calibrate_linear` when `bounds = NULL`).
   - Post-loop: same failed-draw counting, warning, and all-failed error as the
     IPW path; same output assembly (`repwt_names`, `@variables$repweights`,
     history entry with `level = "A"` or `"B"`).

10. **[impl]** Fix `surveywts_warning_bootstrap_draws_failed` "i" bullet text.
    In the post-loop warning block, change:
    ```
    "A draw fails when {.fn ipw} or calibration does not converge (e.g.,
    degenerate propensity scores in the resampled data)."
    ```
    to:
    ```
    "A draw fails when calibration or IPW re-estimation does not converge
    (e.g., degenerate inputs in the resampled data)."
    ```
    Run `devtools::test()` → warning snapshot turns GREEN.

11. **[check]** Run `devtools::document()` (no roxygen2 changes in this PR;
    confirm NAMESPACE unchanged) and `devtools::check()`. Target: 0 errors, 0
    warnings, ≤2 pre-approved notes.

### Acceptance criteria

- [ ] All new tests confirmed failing (RED) before implementation (tasks 2–6)
- [ ] `surveywts_error_qr_bootstrap_requires_nonprob` snapshot does NOT contain "with IPW history"
- [ ] `surveywts_error_qr_bootstrap_no_history` fires on `survey_nonprob` with empty history
- [ ] Calibration-only Level A: `survey_nonprob` returned, `@variables$repweights` length = `replicates`, `test_invariants` passes, weight conservation within 1e-6
- [ ] Calibration-only Level B: same structural assertions; history entry has `level = "B"`
- [ ] All three dispatch-coverage tests (calibrate_linear, calibrate_logit, poststratify) pass
- [ ] Existing IPW-only and doubly-robust path regression tests remain GREEN
- [ ] `surveywts_warning_bootstrap_draws_failed` "i" bullet is path-agnostic (snapshot updated)
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ unchanged

---

## PR 2: Calibration-only DAGJK path

**Branch:** `feature/nps-calib-dagjk`
**Depends on:** PR 1 (squash-merged to develop before this branch opens)

### Files (TDD order)

- `tests/testthat/test-nps-group-jackknife.R` — add calibration-only DAGJK test suite
- `R/create_group_jackknife_weights.R` — routing logic, error class replacement, fix "i" bullets, `.dagjk_single_replicate_calib()` helper, conditional reference/ceiling
- `R/replicate-utils.R` — call `.dispatch_calibration_replay()` (extracted in PR 1; no new implementation here)
- `changelog/replicate/feature-nps-calib-dagjk.md` — created last, before opening PR

### Tasks

1. **[test]** Snapshot cleanup — delete any existing snapshot entries in
   `tests/testthat/_snaps/test-nps-group-jackknife.txt` for the retired class
   `surveywts_error_dagjk_no_ipw_history`. Run `testthat::snapshot_review()`
   after the first full test run to accept the new
   `surveywts_error_dagjk_no_history` snapshot.

2. **[test]** Write failing tests — error paths. In
   `test-nps-group-jackknife.R`, add a labelled section
   `# calibration-only DAGJK — error paths`. Dual blocks for:
   - `surveywts_error_dagjk_no_history` (triggered by `nps_no_history`)
   - `surveywts_error_dagjk_no_reference` (calibration-only Level B, no stored
     reference and no `reference_sample` arg)
   - `surveywts_error_reference_sample_class` (`reference_sample = data.frame(x=1)`)
   - `surveywts_error_dagjk_requires_nonprob` snapshot must NOT contain "IPW weighting history"
   - Existing groups validation errors: `dagjk_groups_invalid`,
     `dagjk_groups_not_whole_number`, `dagjk_groups_too_small`,
     `dagjk_groups_exceeds_n` (Level A ceiling uses n_A only: `nps_calib_a`
     has 500 rows; `groups = 501L` → error)
   - `surveywts_error_dagjk_all_replicates_failed` (calibration to impossible
     targets; `groups = 2L`)

3. **[test]** Write failing tests — calibration-only Level A happy path. Add:
   - Returns `survey_nonprob`; `@variables$repweights` has length 10;
     `test_invariants(result)` passes (`nps_calib_a`, `groups = 10L`,
     `seed = 42L`)
   - Replicate column structure: each row has exactly 1 zero across replicate
     columns
   - History entry: `operation = "group_jackknife_weights"`
   - `@variables$scale = 9/10`; `rscales = rep(1, 10)`; `mse = TRUE`;
     `type = "group-jackknife"`
   - Weight conservation (non-zero rows): within 1e-6 relative
   - Original columns unchanged
   - Reproducibility: same seed gives identical `repwt_1`
   - `reference_sample` supplied for Level A: no error, accepted but unused

4. **[test]** Write failing tests — dispatch coverage. One block each for
   `calibrate_linear`, `calibrate_logit`, `poststratify` as calibration
   operation (Level A). Construct inline, call with `groups = 10L`,
   `seed = 1L`, assert structural invariants.

5. **[test]** Write failing tests — Level B, warning paths, and edge cases.
   - Level B: `nps_calib_b`, `groups = 10L`, `seed = 42L`,
     `reference_sample = ref_data` → `survey_nonprob`; `test_invariants` passes
   - Warning: `surveywts_warning_dagjk_repweights_overwritten` on second call
   - Warning: `surveywts_warning_dagjk_small_groups` (`groups = 499L` on 500-row data)
   - Warning: `surveywts_warning_dagjk_replicates_failed` (degenerate targets;
     result still returned with fewer repwt columns)
   - Defensive test for `surveywts_warning_dagjk_negative_replicate_weights`:
     write a `test_that()` block documenting that the warning is unreachable via
     the calibration-only path (IPF never produces negative weights; `calibrate_linear()`
     negative weights are caught by the S7 validator, converting to
     `surveywts_error_dagjk_degenerate_replicate` before the post-loop check).
     Verify the assembled replicate matrix contains only non-negative values under
     normal calibration-only operation. Do NOT use
     `expect_warning(class = "surveywts_warning_dagjk_negative_replicate_weights")`.
     Follow the existing pattern at `test-nps-group-jackknife.R` lines 694-708 and
     955-965.
   - Edge: Level A groups ceiling uses `n_A` only (501 groups on 500 NPS rows
     → `surveywts_error_dagjk_groups_exceeds_n`)

6. **[test]** Write regression tests — existing paths. Add blocks verifying:
   - IPW-only path (`datasets$A` from `make_dagjk_datasets()`): returns
     `survey_nonprob` with repweights, no error
   - Doubly-robust Level A (`datasets$B`): same
   Confirm these are GREEN before proceeding.

7. **[impl]** Fix "i" bullet in `surveywts_error_dagjk_requires_nonprob` —
   `create_group_jackknife_weights.R`. Change:
   ```
   "The DAGJK for NPS requires an IPW weighting history attached to a
   {.cls survey_nonprob} object."
   ```
   to:
   ```
   "The DAGJK requires a weighting history attached to a
   {.cls survey_nonprob} object."
   ```
   Also update the `"v"` bullet if it references `ipw()` specifically (change
   to generic "Use a calibration or IPW step before calling this function.").
   Run `devtools::test()` → snapshot in task 2 turns GREEN; other snapshots
   remain GREEN.

8. **[impl]** Implement routing logic in `create_group_jackknife_weights()`.
   Replace the existing IPW history check (currently errors with
   `surveywts_error_dagjk_no_ipw_history`) with the new routing logic per
   spec §Validation order, step 5:
   - Find last IPW entry: `$operation == "ipw"`
   - Find last calibration entry: operations in
     `c("calibrate_rake", "calibrate_linear", "calibrate_logit", "poststratify", "raking")`
   - If neither: error `surveywts_error_dagjk_no_history`
   - If IPW found: set `ipw_entry`, continue with existing path (unchanged)
   - If calibration only: set `calib_entry`, set `ipw_entry = NULL`, new path
   Replace step 6 (reference resolution): make it conditional — IPW path
   requires reference (existing behavior); calibration-only Level A: `ref_design = NULL`;
   calibration-only Level B: resolve from `reference_sample` or
   `calib_entry$parameters$reference_design`; if neither: error
   `surveywts_error_dagjk_no_reference`.
   Update step 7 (ceiling check): for Level A calibration-only, pass
   `combined_n = n_nps` to `.validate_groups_arg()` (not `n_nps + n_ref`).

9. **[impl]** Add `.dagjk_single_replicate_calib()` internal helper in
   `create_group_jackknife_weights.R` above `create_group_jackknife_weights()`.
   Signature:
   ```r
   .dagjk_single_replicate_calib <- function(
     g, group_assign, nps_data, ref_data, ref_wt_col,
     calib_entry, n_nps, n_ref, use_level_b, ref_design, wt_col
   )
   ```
   Algorithm per spec §Calibration-only DAGJK algorithm:
   - Identify group-g NPS indices from `group_assign[seq_len(n_nps)]`
   - If Level B: also identify group-g reference indices
   - Form `S_A_minus_g`; check for empty → error `surveywts_error_dagjk_degenerate_replicate`
   - `n_Ag = count of NPS units in group g`; `a_g = n_A / (n_A - n_Ag)`
   - Apply scale factor: `w_i_adj = w_i * a_g` where `w_i` is the CURRENT weight
     from `nps_data[[wt_col]]` (NOT equal weights — this is the key difference from
     the bootstrap calibration-only path)
   - Call `.dispatch_calibration_replay(data, calib_entry, ref_design, use_level_b)`
     from `replicate-utils.R` (extracted in PR 1). Do NOT re-implement the dispatch
     table here.
   - Degenerate check: any NA or non-positive weights → error
     `surveywts_error_dagjk_degenerate_replicate`
   - Return full-length vector: `w_full[nps_keep_idx] <- calibrated_weights`;
     group-g units get 0.

10. **[impl]** Wire calibration-only path in the main loop. In
    `create_group_jackknife_weights()`, inside `for (g in seq_len(groups))`,
    dispatch to `.dagjk_single_replicate_calib()` when `is.null(ipw_entry)`,
    and to `.dagjk_single_replicate()` when `!is.null(ipw_entry)`.
    Update the group assignment step: when `ref_design` is NULL (Level A),
    assign groups over `seq_len(n_nps)` only (not combined NPS + reference rows).
    Update the small-groups warning: use `n_nps` for Level A,
    `n_nps + n_ref` for all other paths.

11. **[check]** Run `devtools::document()` and `devtools::check()`. Target: 0
    errors, 0 warnings, ≤2 pre-approved notes. Run
    `covr::package_coverage()` to verify ≥95% line coverage.

### Acceptance criteria

- [ ] All new tests confirmed failing (RED) before implementation (tasks 2–6)
- [ ] `surveywts_error_dagjk_requires_nonprob` snapshot does NOT contain "IPW weighting history"
- [ ] `surveywts_error_dagjk_no_history` fires on `survey_nonprob` with empty history
- [ ] `surveywts_error_dagjk_no_reference` fires on calibration-only Level B with no reference available (snapshot + class assertion)
- [ ] Calibration-only Level A: `survey_nonprob` returned; repweights length = `groups`; `test_invariants` passes; replicate column structure correct; weight conservation within 1e-6; `scale = (G-1)/G`, `mse = TRUE`, `type = "group-jackknife"`
- [ ] Calibration-only Level B: same structural assertions
- [ ] Level A groups ceiling check uses `n_A` only (not `n_A + n_ref`)
- [ ] All three dispatch-coverage tests (calibrate_linear, calibrate_logit, poststratify) pass
- [ ] All existing IPW-only and doubly-robust path regression tests remain GREEN
- [ ] Reproducibility: same seed produces identical repwt_1 column for calibration-only DAGJK
- [ ] All warning paths pass (overwrite, small groups, replicates failed, negative weights)
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ unchanged
- [ ] `covr::package_coverage()` ≥ 95% overall

---

## Cross-cutting notes

### Error messages.md: already complete
`plans/error-messages.md` already has the new classes (`surveywts_error_qr_bootstrap_no_history`,
`surveywts_error_dagjk_no_history`) and the retired classes
(`~~surveywts_error_qr_bootstrap_no_ipw_history~~`,
`~~surveywts_error_dagjk_no_ipw_history~~`) marked as retired. No changes to
this file are needed in either PR.

### Calibration-only vs. doubly-robust starting weights
- **Bootstrap calibration-only (PR 1):** Each SRSWR replicate assigns equal
  initial weight 1. Do NOT carry forward the original calibrated weights.
- **DAGJK calibration-only (PR 2):** Each group replicate starts from the
  CURRENT weights in `data@data` (the post-calibration weights), scaled by
  `a_g = n_A / (n_A - n_Ag)`. This is a critical distinction from the bootstrap
  path.

### `poststratify()` dispatch
`poststratify()` only accepts `data`, `targets`, and `type`; it does not have
`algorithm`, `cap`, `control`, or `bounds` parameters. The dispatch table must
not forward those parameters to `poststratify()`. For the other three functions,
use `NULL` values for unrecorded parameters (they will use function defaults).

### Parameter storage verification (before coding dispatch)
Per spec §Implementation assumption: calibration parameter storage, verify that
each of the four calibration functions stores its parameters under `$parameters`
in the weighting history entry. If a parameter is absent, the dispatch call will
use the function default. Document any gaps in the PR description rather than
failing silently.

### Snapshot review workflow
After the first `devtools::test()` run that produces new snapshots:
```r
testthat::snapshot_review()
```
Review each diff individually. Do NOT run `testthat::snapshot_accept()` blindly.
