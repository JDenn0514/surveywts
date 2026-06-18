# Changelog: calibrate_to_survey() — Opsomer algorithm (PR 2)

**Date:** 2026-06-17
**Branch:** feature/cts-opsomer-algorithm
**PR:** 2 of 2 (calibrate-to-survey-opsomer pipeline)

## Summary

Implements the Opsomer & Erciulescu (2022) replication variance adjustment
natively in `calibrate_to_survey()`, replacing the prior delegation to
`svrep::calibrate_to_sample()`. Adds the `targets`, `type`, and `algorithm`
arguments introduced in PR 1 to the actual calibration path.

## What changed

### `R/calibrate_to_survey.R`

- **Full Opsomer algorithm** (Steps 1–8 per spec §Algorithm):
  - Step 1: resolve wt_col, var_names, R, R_C, A, A_C
  - Step 2: compute K = max(1, ceiling(R_C / R)); R_eff = K * R
  - Step 3: compute a_r constants (length R_eff); active range has sqrt(A_C/A_eff)
  - Step 4: compute control-survey totals (full-sample and per-replicate) via `.compute_control_totals()`
  - Step 4b: convert `type="prop"` targets to counts using primary N
  - Step 5: draw control column mapping (svrep-matching direction)
  - Step 6: calibrate full-sample weights to combined target set
  - Step 7: per-replicate calibration with perturbed control totals
  - Step 8: build output design preserving input class

- **Removed svrep delegation** from the main calibration path for both
  `targets = NULL` and `targets != NULL`. `.svrep_calibrate_to_sample()` is
  retained as an internal stub for `calibrate_to_estimate()` compatibility.

- **`.calibrate_opsomer_single()`** — new internal helper:
  - Always uses `survey::calibrate()` for all methods (rake/linear/logit)
  - Accepts `intercept_n` param to resolve grand-total inconsistency between
    fixed margins (from `targets`) and random margins (from control survey)
  - Convergence warning detection: captures "converge" warnings, re-signals
    as `surveywts_error_calibration_not_converged` after `tryCatch` exits

- **`.compute_control_totals()`** — new internal helper:
  - Computes full-sample and per-replicate control totals for each calibration variable
  - Returns list of `list(full = named_vector, replicates = matrix)`

- **History entry** — promotes `K`, `a_constants`, `targets`, `type`, and
  `fixed_variables` as top-level fields (in addition to `parameters$…`)

- **Intercept consistency fix** — when `targets` are present, `(Intercept)` is
  set to `sum(targets_counts[[1]])` (primary's N) so fixed margins are
  exactly satisfied; pure control cases continue to use `sum(first_ctrl_var_totals)`

### `R/calibrate-utils.R`

- `.to_svyrep()` and `.method_to_calfun()` moved here from `calibrate_to_survey.R`
  (both still used by `calibrate_to_estimate.R`)

### `tests/testthat/test-sample-calibration.R`

- Sections 26–33 added (PR 2 happy path, a_r correctness, K expansion, fixed
  margins, svrep non-delegation, convergence, negative weights, oracle)
- Three PR 1 svrep-mocking tests replaced with equivalent tests that exercise
  the Opsomer path directly
- Oracle test corrected: uses `result_svrep$pweights` (not `stats::weights()`)
  for full-sample weight comparison
- Negative-weights test redesigned: uses two-variable scenario with extreme
  primary joint distribution that reliably produces negative linear weights
  while allowing all bootstrap replicates to converge
- Tests using `make_nonprob_replicate_design` with `type="prop"` changed to
  `type="count"` with targets scaled to control's N to avoid grand-total
  inconsistency causing convergence failure
- `nest = TRUE` added to jackknife regression guard test to fix PSU nesting error

### `NEWS.md`

- Two breaking change entries added

## Bug fixes during implementation

1. **CCM length mismatch** — `ccm[s_idx]` returns 0 for unmatched positions
   when `R_P > R_C`; guard changed from `s_idx <= R_C` to `ccm[s_idx] > 0L`

2. **Convergence error class** — `cli::cli_abort()` inside `withCallingHandlers(warning=)`
   does not propagate class through `tryCatch`; fixed by recording the convergence
   message, re-signaling after the `tryCatch` block (or inside the error handler
   if survey::calibrate() also throws a hard error)

3. **Grand-total intercept inconsistency** — treatment-contrast `(Intercept)` was
   set from the first control variable's grand total, causing sex fixed margins
   to be off by the primary/control weight-sum difference; resolved by passing
   `intercept_n` explicitly when `targets` are present
