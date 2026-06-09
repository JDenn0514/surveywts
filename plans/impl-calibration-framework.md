# Implementation Plan — calibration-framework

**Status**: PLAN_READY
**Spec**: `plans/spec-calibration-framework.md`
**Test-spec**: `plans/test-spec-calibration-framework.md`
**PR range**: PR 1–5
**Target branch**: `develop`

---

## Overview

This plan delivers the calibration framework redesign specified in
`spec-calibration-framework.md`: two new exported functions
(`calibrate_linear`, `calibrate_logit`), a renamed export (`poststratify`
replacing `calibrate_poststrat`), algorithm updates to `calibrate_rake`
(rename `"anesrake"` → `"classic_ipf"`, add `"nr"`, drop `"survey"`), and
a retargeted `calibrate` dispatcher. The shared Newton-Raphson engine ships
first (PR 1), followed by four function PRs in strict dependency order.

**Key architectural decision — NR engine implementation:** The user directed
either wrapping `survey::calibrate()` directly or implementing based on
`grake.R`. Since `survey` is in Imports (always available), wrapping is
feasible. However, wrapping requires constructing and unwrapping a
`survey::svydesign()` object and mapping survey's internal error conditions
to our typed error classes. Implementing `.calibrate_nr_engine()` directly
modeled on grake.R costs ~60 lines, gives full control over metadata capture
(`lambda`, `n_iterations`, `converged`), integrates cleanly with
`.build_calibration_provenance()`, and maps errors exactly to our classes.
**Decision: implement `.calibrate_nr_engine()` based on grake.R.** Oracle
tests in every PR verify the output matches `survey::calibrate()` within 1e-8.

---

## PR Map

- [x] PR 1: `feature/calibration-nr-engine` — Shared NR engine, calfun objects, `.validate_bounds()`, `.validate_unit_scale()`, migrate `.calibrate_engine()`, update `.build_calibration_provenance()`
- [x] PR 2: `feature/calibrate-linear` — `calibrate_linear()` + delete `calibrate_greg.R`
- [x] PR 3: `feature/calibrate-logit` — `calibrate_logit()`
- [x] PR 4: `feature/calibrate-rake-nr` — `calibrate_rake()` algorithm update + `calibrate()` dispatcher retarget
- [ ] PR 5: `feature/poststratify` — `poststratify()` rename + delete `calibrate_poststrat.R` + error-messages.md Thrown-by cleanup

---

### PR 1: Shared NR calibration engine + validators

**Branch:** `feature/calibration-nr-engine`
**Depends on:** none (cut from `develop`)

**Files (in TDD order — tests first):**
- `plans/error-messages.md` — add `surveywts_error_bounds_invalid_calibration`,
  `surveywts_error_unit_scale_invalid`, `surveywts_error_cap_not_supported_nr`
  if not already present; verify "Thrown by" entries are placeholder-correct
  (final updates come in PR 5)
- `R/calibrate-utils.R` — add 7 items:
  1. `.validate_bounds(bounds, bounds_scale, allow_null)` — validates
     `bounds` against `bounds_scale` rules; throws
     `surveywts_error_bounds_invalid_calibration`
  2. `.validate_unit_scale(unit_scale, n)` — validates unit_scale vector;
     throws `surveywts_error_unit_scale_invalid`
  3. `.make_calfun_linear()` — returns list with `Fm1` and `dF` for linear
     ($F(u) = 1+u$, $F'(u) = 1$); supports optional capping to `[L, U]`
  4. `.make_calfun_logit(L, U)` — returns list with `Fm1` and `dF` for
     logit (spec §Mathematical background formula; $A = (U-L)/[(1-L)(U-1)]$)
  5. `.make_calfun_raking()` — returns list with `Fm1` and `dF` for
     raking ($F(u) = \exp(u)$, $F'(u) = \exp(u)$)
  6. `.calibrate_nr_engine(x_matrix, weights_vec, calfun, population,
     epsilon, maxit)` — Newton-Raphson loop modeled on grake.R:
     initialize `eta = 0`; iterate: compute `g = calfun$Fm1(x_matrix %*% eta)`,
     `deriv = calfun$dF(x_matrix %*% eta)`, build
     `Tmat = t(x_matrix) %*% (weights_vec * deriv * x_matrix)`,
     compute misfit, solve `Deta = solve(Tmat, misfit)`, update `eta`;
     check convergence as `max(|misfit| / (1 + |population|)) < epsilon`;
     step-halve when `solve()` fails or non-finites appear; throw
     `surveywts_error_calibration_singular_system` when `Tmat` is singular
     after retries; throw `surveywts_error_calibration_not_converged` on
     exhaustion; return `list(weights, lambda, n_iterations, converged)`
  7. Move `.calibrate_engine()` from `R/calibrate_greg.R` into
     `calibrate-utils.R` verbatim — no behavioral change; keeps
     `calibrate_rake.R` working after `calibrate_greg.R` is deleted in PR 2
- Update `.build_calibration_provenance()` in `R/calibrate-utils.R`:
  - Add `bounds_scale` parameter (stored in returned list)
  - Change `lambda` logic: accept `lambda` as an explicit argument rather
    than computing it post-hoc from `crossproduct_inv %*% discrepancy`
    (the NR engine returns the converged lambda directly)
  - The existing `crossproduct_inv` computation stays for linear (where it
    equals the NR Jacobian inverse at convergence); for logit and raking,
    the engine may return `crossproduct_inv = NULL`
- `changelog/calibration-framework/feature-calibration-nr-engine.md` — write last

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began — N/A
  for this PR (pure infrastructure; engine is tested through public API in PR 2–3)
- [ ] Coverage exemption: PR 1 is exempt from the standalone 98%/95% coverage
  gate. Coverage over the NR engine code lands in PR 2. Full coverage verified
  post-PR 2.
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] `calibrate_rake()` still passes all existing tests after `.calibrate_engine()`
  is moved from `calibrate_greg.R` to `calibrate-utils.R`
- [ ] `plans/error-messages.md` updated with 3 new error classes
- [ ] Changelog entry written

**Notes:**
- No new exported symbols in this PR — all additions are internal (`.`-prefixed)
- The `.calibrate_engine()` migration is a move, not a rewrite — behavior is
  identical; calibrate_rake.R must not be changed in this PR
- `.calibrate_nr_engine()` must handle the plain-linear case in a single step:
  for the linear calfun, the NR update converges in iteration 1 because
  $F'(u) = 1$ makes the Jacobian exact. Verify `n_iterations == 1L` for
  any linear call with `bounds = NULL`
- Step-halving guard (from grake.R): if `any(!is.finite(g))` after computing
  g-weights, bisect `eta` toward zero and retry (up to 20 halvings) before
  declaring non-convergence
- Bounds for the linear truncated case are applied inside `calfun$Fm1` via
  clamping: `min(max(1 + u, L), U) - 1`

---

### PR 2: `calibrate_linear()` + delete `calibrate_greg.R`

**Branch:** `feature/calibrate-linear`
**Depends on:** PR 1

**Files (in TDD order — tests first):**
- `tests/testthat/test-calibrate-linear.R` — full test suite: happy paths
  H1–H10, oracle tests N1–N2, error paths E1–E23, warning paths W1–W4,
  edge cases EC1–EC11 (all red before implementation)
- `R/calibrate_linear.R` — new exported function
- `man/calibrate_linear.Rd` — generated by `devtools::document()`
- `NAMESPACE` — generated
- `changelog/calibration-framework/feature-calibrate-linear.md` — write last

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Happy path tests H1–H10 pass
- [ ] Oracle tests N1–N2 pass (within 1e-8; `skip_if_not_installed("survey")`
  inside each block)
- [ ] Error paths E1–E23 pass (dual: `expect_error(class=...)` +
  `expect_snapshot(error = TRUE, ...)`)
- [ ] Warning paths W1–W4 pass
- [ ] Edge cases EC1–EC11 pass
- [ ] `test_invariants(obj)` is the **first** assertion in every block that
  creates a `weighted_df` or `survey_nonprob`
- [ ] Quality gate 7: `@calibration$n_iterations == 1L` for `bounds = NULL`
  (EC10: assert `expect_equal(obj@calibration$n_iterations, 1L)`)
- [ ] Quality gate 7: `n_iterations > 1L` for `bounds != NULL` with non-trivial
  targets (EC11)
- [ ] `@calibration$method == "linear"` for `bounds = NULL`;
  `"truncated"` for `bounds != NULL` (H6)
- [ ] `@calibration$bounds_scale == "multiplicative"` for H6 (default scale with
  `bounds = c(0.3, 3)`); `is.null(@calibration$bounds_scale)` for H1 (`bounds = NULL`)
- [ ] `is.null(@calibration$q_weights)` for H1 (`unit_scale = NULL`); for any
  test supplying `unit_scale`, assert `@calibration$q_weights` equals the supplied vector
- [ ] Quality gate 6: weight conservation EC8 (`type = "count"`, 1e-10) and
  EC9 (`type = "prop"`, 1e-10)
- [ ] `surveywts_warning_negative_calibrated_weights` emitted for plain
  linear with extreme targets (H10/W2); `test_invariants(result)` after
  warning capture
- [ ] Gotcha EC7: g-weights (`new_wt / base_wt`) in `[L, U]`, not raw weights
- [ ] H_abs: `bounds = c(200, 2000)`, `bounds_scale = "absolute"` — verify all
  output weights (not g-weights) are in `[200, 2000]`; i.e., `all(wt >= 200 & wt <= 2000)`
- [ ] E_abs: `bounds = c(-1, 2)`, `bounds_scale = "absolute"` → `surveywts_error_bounds_invalid_calibration`
  (L <= 0 rule for absolute scale)
- [ ] Test coverage ≥ 98% overall
- [ ] Changelog entry written

**Notes:**
- Signature: `calibrate_linear(data, targets, weights = NULL, wt_name = "wts",
  bounds = NULL, bounds_scale = c("multiplicative", "absolute"),
  unit_scale = NULL, type = c("prop", "count"), control = list(),
  reference_design = NULL)`
- SRS assumption: plain `data.frame` + `weights = NULL` → uniform weights
  (each = 1; `sum = n`); emit `surveywts_warning_srs_no_weights`
- Proportion-to-count conversion: multiply targets by `N = sum(design_weights)`
  before entering engine, matching `survey::calibrate()` convention
- `bounds_scale = "absolute"`: convert absolute bounds to multiplicative before
  passing to engine: `L_mult = L / d_k` per unit, then pass to calfun. Wait —
  absolute bounds constrain `w_k` directly, not `g_k`. For the NR engine,
  pass the per-unit effective bounds to the calfun clamping in `.make_calfun_linear()`.
  Alternative simpler approach: scale the weights by `1/d_k` internally so the
  engine works in g-weight space, then convert back. Document this as an
  implementation gotcha in the PR notes.
- `survey_replicate` input: for `type = "count"`, scale population totals per
  replicate by `sum(rep_wt) / sum(base_wt)` before each replicate's engine call
- History `operation`: `"calibrate_linear"`
- `calibrate_greg.R` is NOT deleted in this PR — it stays in place because
  `calibrate.R` still dispatches to `calibrate_greg()` until PR 4.
  Deletion is deferred to PR 4 where `calibrate.R` stops calling it.

---

### PR 3: `calibrate_logit()`

**Branch:** `feature/calibrate-logit`
**Depends on:** PR 2

**Files (in TDD order — tests first):**
- `tests/testthat/test-calibrate-logit.R` — full test suite: happy paths
  H1–H10, oracle test N1, error paths E1–E23, warning paths W1–W3, edge cases
  EC1–EC4 (all red before implementation)
- `R/calibrate_logit.R` — new exported function
- `man/calibrate_logit.Rd` — generated
- `NAMESPACE` — generated
- `changelog/calibration-framework/feature-calibrate-logit.md` — write last

**Acceptance criteria:**
- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
- [ ] Happy path tests H1–H10 pass
- [ ] Oracle test N1 passes (`survey::calibrate(calfun = "logit")`, within 1e-8;
  `skip_if_not_installed("survey")` inside block)
- [ ] Error paths E1–E23 pass (dual: `expect_error(class=...)` +
  `expect_snapshot(error = TRUE, ...)`)
- [ ] Warning paths W1–W3 pass
- [ ] Edge cases EC1–EC4 pass
- [ ] `test_invariants(obj)` is the **first** assertion in every block that
  creates a `weighted_df` or `survey_nonprob`
- [ ] EC2: all output weights strictly positive for any valid input (`all(weights > 0)`)
- [ ] EC3: g-weights in open interval `(L, U)` — never exactly at boundary;
  assert `all(new_wt / base_wt > L) && all(new_wt / base_wt < U)` for
  `bounds_scale = "multiplicative"`
- [ ] EC4: `@calibration$lambda` is the converged NR lambda — not the
  one-step linear approximation `T_x^{-1} * discrepancy`
- [ ] `@calibration$bounds_scale == "multiplicative"` for default call;
  `is.null(@calibration$bounds_scale)` not applicable (logit always has bounds)
- [ ] `is.null(@calibration$q_weights)` for any call without `unit_scale`; for
  any test supplying `unit_scale`, assert `@calibration$q_weights` equals the supplied vector
- [ ] Quality gate 1: all output weights positive (enforced by logit calfun)
- [ ] Quality gate 5: `@calibration$lambda` is the NR converged solution
- [ ] H_abs: `bounds = c(200, 2000)`, `bounds_scale = "absolute"` — verify all
  output weights are in `[200, 2000]`; i.e., `all(wt > 200 & wt < 2000)` (open
  interval for logit)
- [ ] E_abs: `bounds = c(-1, 2)`, `bounds_scale = "absolute"` → `surveywts_error_bounds_invalid_calibration`
  (L <= 0 rule for absolute scale)
- [ ] Test coverage ≥ 98% overall
- [ ] Changelog entry written

**Notes:**
- Signature: `calibrate_logit(data, targets, weights = NULL, wt_name = "wts",
  bounds = c(1e-6, 1e6), bounds_scale = c("multiplicative", "absolute"),
  unit_scale = NULL, type = c("prop", "count"), control = list(),
  reference_design = NULL)`
- Default bounds `c(1e-6, 1e6)` — matches `survey::calibrate(calfun = "logit")`
- Logit calfun scaling constant: `A = (U - L) / ((1 - L) * (U - 1))`; with
  default bounds, `A ≈ 1.000001` (negligibly > 1 for practical purposes)
- Lambda is the final `eta` vector from `.calibrate_nr_engine()` — do NOT
  recompute as `T_x^{-1} * discrepancy` after convergence (that would be the
  linear approximation, not the logit solution)
- For `bounds_scale = "absolute"`: same conversion as `calibrate_linear()`
  (scale input weights and targets to g-weight space, run engine, convert back)
- History `operation`: `"calibrate_logit"`
- The only meaningful difference from `calibrate_linear()` is the calfun
  (`.make_calfun_logit(L, U)` instead of `.make_calfun_linear()`); the
  surrounding orchestration code is nearly identical — resist the temptation to
  abstract prematurely. Two explicit functions is clearer than one parameterized
  function

---

### PR 4: `calibrate_rake()` algorithm update + `calibrate()` dispatcher retarget

**Branch:** `feature/calibrate-rake-nr`
**Depends on:** PR 3

**Files (in TDD order — tests first):**
- `tests/testthat/test-03-rake.R` — rename all `algorithm = "anesrake"` to
  `"classic_ipf"`, all `algorithm = "survey"` tests to expect
  `rlang::arg_match()` error; add NR-specific test blocks for H6–H8, H10,
  N1, E17–E20, EC3–EC9 (write new blocks red first, update existing)
- `tests/testthat/test-02-calibrate.R` — update dispatcher tests: add H1–H8,
  E1–E2, EC1–EC3; update `method` default from `"linear"` to `"rake"`; add
  cross-function tests CX1–CX3 (expect_equal dispatch identity)
- `R/calibrate_rake.R` — rename `"anesrake"` → `"classic_ipf"` everywhere;
  remove `"survey"` option; add `"nr"` path using `.calibrate_nr_engine()`;
  remove `bounds` argument; update all control-param warning logic; update
  `@calibration` slot population for both algorithms
- `R/calibrate.R` — dispatcher: update `method` arg to
  `c("rake", "linear", "logit")`; default to `"rake"`; update dispatch
  targets; update docs
- `R/calibrate_greg.R` — DELETE (`.calibrate_engine()` already moved in PR 1;
  `calibrate.R` no longer calls `calibrate_greg()` after this PR)
- `man/calibrate_rake.Rd` — generated
- `man/calibrate.Rd` — generated
- `man/calibrate_greg.Rd` — deleted (generated by `devtools::document()`)
- `NAMESPACE` — generated
- `changelog/calibration-framework/feature-calibrate-rake-nr.md` — write last

**Acceptance criteria:**
- [ ] All new and modified tests confirmed red before implementation changes
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
  (`calibrate_greg.Rd` removed)
- [ ] `calibrate_rake()` happy paths H1–H14 pass (including H6–H8 for "nr")
- [ ] Oracle tests N1 (`survey::calibrate(calfun = "raking")`, 1e-8) and N2
  (`survey::rake()`, 1e-6) pass; `skip_if_not_installed("survey")` inside each
- [ ] Error paths E1–E20 pass (dual pattern for E17–E20; arg_match for
  unknown algorithm)
- [ ] Warning paths W1–W4 pass
- [ ] Message path M1 passes (`surveywts_message_already_calibrated` for
  classic_ipf when data already at targets)
- [ ] Edge cases EC1–EC9 pass
- [ ] EC5: `@calibration$lambda` is numeric vector for `algorithm = "nr"`
- [ ] EC6: `@calibration$lambda` is `NULL` for `algorithm = "classic_ipf"`
- [ ] EC1: `surveywts_error_cap_not_supported_nr` before any computation
- [ ] Quality gate 6: weight conservation EC7–EC8 within 1e-10
- [ ] EC9: replicate population-total scaling for `type = "count"` (each
  replicate's target scaled by `sum(rep_wt) / sum(base_wt)`)
- [ ] `calibrate()` happy paths H1–H8 pass
- [ ] `calibrate()` EC1–EC3: dispatch identity — result identical to direct call
- [ ] Cross-function tests CX1–CX3 pass (`expect_equal` for same args)
- [ ] All formerly `"anesrake"` tests pass under `"classic_ipf"`
- [ ] `"survey"` algorithm triggers arg_match error (not a separate typed error)
- [ ] Test coverage ≥ 98%
- [ ] Changelog entry written

**Notes:**
- `calibrate_rake()` "nr" path: build model matrix using same treatment-contrast
  parameterization as the existing survey-object path (`stats::model.matrix(~
  var1 + var2, data = ...)`); call `.calibrate_nr_engine()` with raking calfun;
  store converged `eta` as `lambda` in `@calibration`
- For "nr": `@calibration$crossproduct_inv` is the NR Jacobian inverse at
  convergence (the Tmat solve result from the final iteration), or `NULL` if
  the engine doesn't expose it — simpler to store `NULL` and leave it for a
  future iteration
- Control params for "classic_ipf": `maxit`, `improvement`, `pval`,
  `min_cell_n`, `variable_select` — unrecognized keys warn
- Control params for "nr": `maxit`, `epsilon` — unrecognized keys warn;
  also warn if classic_ipf-only keys (`pval`, `improvement`, etc.) are supplied
  with `algorithm = "nr"`
- `calibrate.R` dispatcher: `method` goes at the end of the signature so `...`
  forwards method-specific args (`bounds`, `algorithm`, `cap`, etc.) to the
  dispatched function. No validation in `calibrate()` itself — all errors
  propagate from the dispatched function. `calibrate.R` itself does not reference
  `calibrate_greg` or `calibrate_poststrat` after this PR.
- After deleting `calibrate_greg.R`, verify: `grep -r "calibrate_greg" R/`
  returns 0 hits.

---

### PR 5: `poststratify()` + cleanup

**Branch:** `feature/poststratify`
**Depends on:** PR 4

**Files (in TDD order — tests first):**
- `tests/testthat/test-04-poststratify.R` — rename all `calibrate_poststrat()`
  calls to `poststratify()`; update history operation assertions from
  `"calibrate_poststrat"` to `"poststratify"`; update any error snapshot files;
  add error paths E13–E18 if not already present (named list input → E5;
  `surveywts_error_empty_stratum` → W2 replicate path); add EC5 operation
  string assertion; add EC6 `cell_factors` assertion; cross-function CX4
- `R/utils.R` — update `.format_history_step()`: add `"calibrate_linear"` and
  `"calibrate_logit"` cases (show target variable names, matching the pattern of
  `"calibrate_rake"`); remove the stale `"calibrate_greg"` / `"calibration"` arm
- `R/poststratify.R` — new file; content = rewrite of `calibrate_poststrat.R`
  with: function name updated; history `operation` changed to `"poststratify"`;
  `targets` must be a `data.frame` (reject named lists with
  `surveywts_error_margins_format_invalid`); `surveywts_error_no_strata_variables`
  when `targets` has no non-`"target"` columns; for `survey_replicate`, no
  population-total scaling (use targets as-is per replicate); `cell_factors`
  stored in `@calibration`
- `R/calibrate_poststrat.R` — DELETE
- `plans/error-messages.md` — update four "Thrown by" entries per spec §Scope:
  `surveywts_warning_negative_calibrated_weights` (remove `calibrate_greg`,
  add `calibrate_linear`); `surveywts_warning_replicate_calibration_failed`
  (remove `calibrate_greg`, `calibrate_poststrat`, add `calibrate_linear`,
  `calibrate_logit`, `poststratify`); `surveywts_warning_control_param_ignored`
  (remove `calibrate_greg`, add `calibrate_linear`, `calibrate_logit`);
  `surveywts_message_already_calibrated` (remove `"anesrake"`, add `"classic_ipf"`)
- `tests/testthat/_snaps/test-04-poststratify.md` — update snapshots for
  renamed function in error messages; run `testthat::snapshot_review()` to
  review each diff
- `man/poststratify.Rd` — generated
- `man/calibrate_poststrat.Rd` — deleted
- `NAMESPACE` — generated
- `changelog/calibration-framework/feature-poststratify.md` — write last

**Acceptance criteria:**
- [ ] All new and modified tests confirmed red before implementation changes
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ in sync
  (`calibrate_poststrat.Rd` removed, `poststratify.Rd` added)
- [ ] Happy path tests H1–H9 pass
- [ ] Oracle tests N1–N2 pass (`survey::postStratify`, within 1e-8)
- [ ] Error paths E1–E18 pass (dual pattern)
- [ ] Warning paths W1–W2 pass (W2 triggers `surveywts_error_empty_stratum`
  in replicate path → caught → `surveywts_warning_replicate_calibration_failed`)
- [ ] Edge cases EC1–EC7 pass
- [ ] `test_invariants(obj)` first assertion in every applicable block
- [ ] EC5: `history[[length(history)]]$operation == "poststratify"` (not
  `"calibrate_poststrat"`)
- [ ] EC6: `output@calibration$cell_factors` == `target_counts / ht_estimates`
  per cell for `survey_taylor` input
- [ ] EC1: named list `targets` → `surveywts_error_margins_format_invalid`
- [ ] Cross-function test CX4: four distinct operation strings for one call
  each of `calibrate_linear`, `calibrate_logit`, `calibrate_rake`, `poststratify`
- [ ] All snapshot updates reviewed via `testthat::snapshot_review()` (not
  bulk-accepted)
- [ ] `.format_history_step()` displays variable names for `"calibrate_linear"`
  and `"calibrate_logit"` operations (not bare operation strings)
- [ ] Stale `"calibrate_greg"` / `"calibration"` arm removed from
  `.format_history_step()`
- [ ] `plans/error-messages.md` "Thrown by" entries updated
- [ ] Test coverage ≥ 98%
- [ ] Changelog entry written

**Notes:**
- `poststratify()` is a rename + documentation update — the algorithm is
  identical to `calibrate_poststrat()`. No numerical behavior changes.
- The replicate path differs from `calibrate_linear()`: for `survey_replicate`,
  **no** population-total scaling. Targets are used as-is for each replicate
  (spec: "cell proportions or counts are used as provided for each replicate").
  This is because post-stratification uses cell ratios, not marginal sums.
- `surveywts_error_empty_stratum` is only reachable in the replicate path
  (when `sum(rep_wt[cell]) == 0` for any cell). The full-sample path is
  guarded by `surveywts_error_weights_nonpositive` before cell computation.
- Snapshot tests in `test-04-poststratify.R` will fail because function name
  in error messages changes. All must be reviewed individually.
- After this PR, `calibrate_poststrat` appears nowhere in R/ or tests/.
  Verify with: `grep -r "calibrate_poststrat" R/ tests/` should return 0 hits.

---

## File Surface Summary

| File | PR | Action |
|------|----|--------|
| `plans/error-messages.md` | 1, 5 | Add 3 new classes (PR 1); update Thrown-by (PR 5) |
| `R/calibrate-utils.R` | 1 | Add NR engine, calfun objects, validators; move `.calibrate_engine()` |
| `R/calibrate_linear.R` | 2 | CREATE |
| `R/calibrate_greg.R` | 4 | DELETE (moved from PR 2; deleted in same PR that stops calling it) |
| `R/calibrate_logit.R` | 3 | CREATE |
| `R/calibrate_rake.R` | 4 | MODIFY (algorithm rename + NR path) |
| `R/calibrate.R` | 4 | MODIFY (dispatcher retarget + default) |
| `R/calibrate_poststrat.R` | 5 | DELETE |
| `R/poststratify.R` | 5 | CREATE |
| `R/utils.R` | 5 | MODIFY (`.format_history_step()`: add linear/logit cases, remove stale greg arm) |
| `tests/testthat/test-calibrate-linear.R` | 2 | CREATE |
| `tests/testthat/test-calibrate-logit.R` | 3 | CREATE |
| `tests/testthat/test-03-rake.R` | 4 | MODIFY |
| `tests/testthat/test-02-calibrate.R` | 4 | MODIFY |
| `tests/testthat/test-04-poststratify.R` | 5 | MODIFY |
| `man/*.Rd` | All | Generated by `devtools::document()` |
| `NAMESPACE` | All | Generated by `devtools::document()` |
| `changelog/calibration-framework/feature-*.md` | Each | Created per PR |

## Write-surface isolation

| PRs | Shared files | Notes |
|-----|-------------|-------|
| PR 1 ∩ PR 2 | `calibrate-utils.R` | PR 1 writes it; PR 2 reads it only |
| PR 2 ∩ PR 4 | `calibrate.R` | PR 2 leaves it unchanged; PR 4 modifies it |
| PR 3 ∩ PR 4 | none | no overlap |
| PR 4 ∩ PR 5 | none | no overlap |

No two concurrent PRs write the same file — safe to run PR 1 standalone, then
PRs 2–5 in strict sequence.

Note: `calibrate_greg.R` deletion moved to PR 4 (from PR 2) so it is deleted
in the same PR that removes all callers. `calibrate_greg.R` is read-only in
PR 2 — no write-surface conflict.
