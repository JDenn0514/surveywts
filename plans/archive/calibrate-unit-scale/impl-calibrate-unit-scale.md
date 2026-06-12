# Implementation Plan — calibrate-unit-scale

**Status**: DRAFT
**Spec**: `plans/spec-calibrate-unit-scale.md`
**Test-spec**: `plans/test-spec-calibrate-unit-scale.md`
**PR range**: PR 1 (single PR)
**Target branch**: `develop`

---

## Overview

This plan delivers three coordinated fixes to the Newton-Raphson calibration
engine and its callers: (D1) `q_weights` applied to `u_vec`, (D2) `q_weights`
applied to the Jacobian, (D3) `q_weights` applied to the step-halving guard,
and (D6) replacement of the `mean(d_k)` absolute-bounds approximation with
exact per-unit `L_k = L_abs / d_k`, `U_k = U_abs / d_k` vector bounds. A
body fix to `.make_calfun_logit()` is also required to handle vector `L`/`U`
arguments without dimension mismatches. Three source files are modified
(`calibrate-utils.R`, `calibrate_linear.R`, `calibrate_logit.R`). No new
exports, no NAMESPACE changes, no signature changes.

---

## PR Map

- [x] PR 1: `feature/calibrate-unit-scale` — Wire `q_weights` through the NR engine and all call sites; fix per-unit absolute bounds (D1–D3, D6)

---

### PR 1: Wire `q_weights` + per-unit absolute bounds

**Branch:** `feature/calibrate-unit-scale`
**Depends on:** none (cut from `develop`)

**Files (in TDD order — tests first):**

- `plans/error-messages.md` — extend `surveywts_error_bounds_invalid_calibration`
  Condition column to include the new `calibrate_logit()` per-unit absolute-bounds
  trigger: thrown when any base weight `d_k ≤ L_abs` (making `L_vec[k] ≥ 1`) or
  `d_k ≥ U_abs` (making `U_vec[k] ≤ 1`), rendering the logit calfun ill-defined
- `tests/testthat/helper-test-data.R` — add shared test fixtures used by both
  test files: `df_500 = make_surveywts_data(n = 500, seed = 42)`,
  `df_200 = make_surveywts_data(n = 200, seed = 7)`,
  `q_unequal = { set.seed(99); exp(rnorm(500, 0, 0.3)) }`,
  `q_all_twos = rep(2, 500)`, and `q_all_ones = rep(1, 500)`; defined at file
  top level so all `test_that()` blocks in both test files can reference them
  without re-running `set.seed()`
- `tests/testthat/test-calibrate-linear.R` — add new test blocks (all red before
  implementation):
  - **Happy paths HL-1 through HL-12**: HL-1 is the regression guard
    (`unit_scale = rep(1, n)` weights identical to `unit_scale = NULL` within
    `1e-14`); oracle comparisons with `survey::calibrate(variance = 1/q)`
    (HL-2, HL-3, HL-4), constraint satisfaction (HL-5), history entry records
    `unit_scale` (HL-6), outputs differ between bounded/unbounded (HL-7),
    absolute-bounds oracle `bounds.const = TRUE` (HL-8), equal-weights
    absolute-bounds parity (HL-9), unequal-weights absolute-bounds differs from
    old mean-based approach (HL-10), absolute-bounds + `unit_scale = q_unequal`
    combined oracle `bounds.const = TRUE, variance = 1/q_unequal` (HL-11),
    unbounded linear converges in exactly 1 NR iteration with `unit_scale =
    q_unequal` — `n_iterations == 1L` in `weighting_history` (HL-12)
  - **Warning path HLW-1**: negative weights warning still fires when `unit_scale != NULL`
  - **Error paths HLE-1 through HLE-5**: dual pattern for all five
  - **Replicate loop RL-1, RL-2, RL-5**: full-sample oracle match (RL-1);
    `unit_scale = NULL` vs `rep(1, n)` identical on replicate input (RL-2);
    absolute-bounds replicate path — all weights in every replicate column
    satisfy `w_k >= L_abs` and `w_k <= U_abs`, `test_invariants(result)` first
    (RL-5)
  - **Edge cases EC-1, EC-2, EC-3, EC-4, EC-5, EC-6, EC-8, EC-9** (linear-specific
    or shared): single-row with `q = 2` (EC-1), uniform small `q` converges (EC-2),
    uniform large `q` converges (EC-3), one extreme entry with `q_k = 1e8` on one
    unit of a 20-unit dataset (EC-4), explicit `rep(1, n)` identical to `NULL`
    (EC-5), multiplicative bounds with `q_unequal` (EC-6), absolute bounds
    equal-weights regression guard (EC-8), absolute bounds final weights all in
    `[L_abs, U_abs]` (EC-9)
  - **EC-4 test pattern**: `result <- tryCatch(calibrate_linear(..., unit_scale =
    q_extreme), error = function(e) e)`; if `inherits(result, "error")` then
    `expect_s3_class(result, "surveywts_error_calibration_singular_system")`; else
    `test_invariants(result)` and verify calibration constraint holds for non-extreme
    units
- `tests/testthat/test-calibrate-logit.R` — add new test blocks (all red before
  implementation):
  - **Happy paths HG-1 through HG-10**: HG-1 is the regression guard
    (`unit_scale = rep(1, n)` identical to `unit_scale = NULL` within `1e-14`);
    same pattern as linear section for HG-2 through HG-9; HG-7 uses oracle
    `survey::calibrate(calfun = "logit", bounds.const = TRUE)`; HG-10 adds
    absolute-bounds + `unit_scale = q_unequal` combined oracle
    (`calfun = "logit"`, `bounds.const = TRUE`, `variance = 1/q_unequal`)
  - **Error paths HGE-1 through HGE-5**: dual pattern for all five; HGE-4 and
    HGE-5 are the new per-unit logit precondition errors
  - **Replicate loop RL-3, RL-4, RL-6**: full-sample oracle match vs
    `survey::calibrate(calfun = "logit", variance = 1/q_unequal)` (RL-3);
    `unit_scale = NULL` vs `rep(1, n)` identical on replicate input (RL-4);
    absolute-bounds replicate path — all base weights strictly inside
    `(L_abs, U_abs)`, calibration constraint holds on full-sample weights,
    `test_invariants(result)` first (RL-6)
  - **Edge cases EC-7, EC-10** (logit-specific): logit g-weights in open interval
    (EC-7), absolute-bounds logit final weights strictly in `(L_abs, U_abs)` (EC-10)
- `R/calibrate-utils.R`:
  1. Add `q_weights = NULL` parameter to `.calibrate_nr_engine()`; resolve to
     `rep(1, nrow(x_matrix))` at entry if `NULL`
  2. Apply D1 fix: `u_vec <- q_weights * drop(x_matrix %*% lambda)`
  3. Apply D2 fix: `jacobian <- t(x_matrix) %*% ((weights_vec * df_vals * q_weights) * x_matrix)`
  4. Apply D3 fix: step-halving check uses
     `calfun$Fm1(q_weights * drop(x_matrix %*% lambda_new))`
  5. Apply convergence-check fix: `u_new <- q_weights * drop(x_matrix %*% lambda)` at
     the post-update convergence evaluation
  6. Fix `.make_calfun_logit()`: add scalar-compat subsetting of `L` and `U` inside
     both the `large_pos` and `normal` branches (spec §Architecture `.make_calfun_logit()`)
- `R/calibrate_linear.R`:
  1. **Call site 1 (bounded-absolute, full-sample)**: replace `scale_factor` /
     `scaled_weights` / `scaled_population` approach with per-unit
     `L_vec = abs_L / weights_vec`, `U_vec = abs_U / weights_vec`; build calfun with
     vector bounds; call engine with original `weights_vec` and
     `population_totals_vec`; add `q_weights = q_for_engine`
  2. **Call site 2 (bounded-multiplicative, full-sample)**: add
     `q_weights = q_for_engine`
  3. **Call site 3 (unbounded, full-sample)**: add `q_weights = q_for_engine`
  4. **Call site 4 (replicate loop, bounded-absolute branch)**: replace
     `rep_scale` / `rep_scaled_wt` / `rep_scaled_pop` approach with per-replicate
     `rep_L_vec = abs_L / rep_wt`, `rep_U_vec = abs_U / rep_wt`; build `rep_calfun`
     with vector bounds; call engine with `rep_wt` and `rep_pop_vec`; add
     `q_weights = q_for_engine`
  5. **Call site 5 (replicate loop, all other branches)**: add
     `q_weights = q_for_engine`
- `R/calibrate_logit.R`:
  1. **Call site 1 (absolute-bounds, full-sample)**: replace `scale_factor` /
     `L_g` / `U_g` / `scaled_weights` / `scaled_population` / `* scale_factor`
     approach with per-unit `L_vec = abs_L / weights_vec`, `U_vec = abs_U /
     weights_vec`; add precondition check
     `all(weights_vec > abs_L & weights_vec < abs_U)` before building calfun (throw
     `surveywts_error_bounds_invalid_calibration` if violated); call engine with
     original `weights_vec` and `population_totals_vec`; add `q_weights = q_for_engine`
  2. **Call site 2 (multiplicative-bounds, full-sample)**: add
     `q_weights = q_for_engine`
  3. **Call site 3 (replicate loop, absolute branch)**: replace `rep_scale` /
     `rep_L_g` / `rep_U_g` / `rep_scaled_wt` / `rep_scaled_pop` / `* rep_scale`
     approach with per-replicate `rep_L_vec = abs_L / rep_wt`, `rep_U_vec = abs_U /
     rep_wt`; add precondition check `all(rep_wt > abs_L & rep_wt < abs_U)` before
     building `rep_calfun` (throw `surveywts_error_bounds_invalid_calibration` if
     violated; this is caught by the `tryCatch()` wrapper and emits
     `surveywts_warning_replicate_calibration_failed`); call engine with `rep_wt`
     and `rep_pop_vec`; add `q_weights = q_for_engine`
  4. **Call site 4 (replicate loop, multiplicative branch)**: add
     `q_weights = q_for_engine`
- `changelog/calibrate-unit-scale/feature-calibrate-unit-scale.md` — created last,
  before opening PR

**Acceptance criteria:**

- [ ] All new tests confirmed failing (red) before implementation began
- [ ] `devtools::check()` 0 errors, 0 warnings, ≤2 pre-approved notes
- [ ] `devtools::document()` run; NAMESPACE and man/ unchanged (no new exports)
- [ ] **Regression gate**: `unit_scale = NULL` produces weights numerically
  identical to pre-fix behavior for all existing tests; `unit_scale = rep(1, n)`
  identical to `unit_scale = NULL` within `1e-14` (HL-1, HG-1)
- [ ] **Oracle gate (linear)**: HL-2, HL-3, HL-4 pass within `1e-8` against
  `survey::calibrate(variance = 1/q_unequal)` (inside `skip_if_not_installed("survey")`)
- [ ] **Oracle gate (absolute bounds)**: HL-8, HG-7 pass within `1e-8` against
  `survey::calibrate(bounds.const = TRUE)` (inside `skip_if_not_installed("survey")`;
  additionally check `packageVersion("survey") >= "4.1"` or skip)
- [ ] **Oracle gate (logit)**: HG-2, HG-3, HG-4 pass within `1e-8` against
  `survey::calibrate(calfun = "logit", variance = 1/q_unequal)`
- [ ] **Oracle gate (absolute bounds + unit_scale, linear)**: HL-11 passes within
  `1e-8` against `survey::calibrate(bounds.const=TRUE, variance=1/q_unequal)`
- [ ] **Oracle gate (absolute bounds + unit_scale, logit)**: HG-10 passes within
  `1e-8` against `survey::calibrate(calfun="logit", bounds.const=TRUE, variance=1/q_unequal)`
- [ ] **D2 Jacobian gate**: HL-12 — `weighting_history[[1]]$convergence$iterations == 1L`
  for unbounded linear with `unit_scale = q_unequal`; confirms correct Jacobian weighting
- [ ] **Oracle gate (logit replicate, RL-3)**: full-sample weight column matches
  `survey::calibrate(calfun="logit", variance=1/q_unequal)` within `1e-8`
- [ ] **Calibration constraint**: HL-5 passes within `1e-8` and HG-5 passes
  within `1e-6` for any `unit_scale != NULL`
- [ ] **History records unit_scale**: HL-6 and HG-6 — `weighting_history` entry
  contains the `unit_scale` vector used for the calibration call
- [ ] **History records n_iterations**: all full-sample calibration calls record
  `weighting_history[[entry]]$convergence$iterations` as a positive integer
- [ ] **Bounded vs unbounded differ**: HL-7 — outputs differ when the same `q`
  is applied with and without bounds
- [ ] **D6 absolute-bounds invariant (linear)**: EC-9 — all final weights satisfy
  `w_k >= L_abs` and `w_k <= U_abs` for every unit; fails without the fix
- [ ] **D6 absolute-bounds invariant (logit)**: EC-10 — all final weights strictly
  in `(L_abs, U_abs)`; fails without the fix
- [ ] **D6 inequality guard**: HL-10 and HG-9 — post-fix output differs from the
  old `mean(d_k)` approximation for unequal base weights
- [ ] **New logit precondition errors**: HGE-4 and HGE-5 throw
  `surveywts_error_bounds_invalid_calibration` with dual pattern
- [ ] **Pre-existing error paths unchanged**: HLE-1 through HLE-4, HGE-1 through
  HGE-3 still pass with dual pattern
- [ ] **HLE-5 dual pattern**: `surveywts_error_calibration_not_converged` tested
  with both `expect_error(class = ...)` and `expect_snapshot(error = TRUE)`
- [ ] **Replicate propagation**: RL-1 and RL-3 full-sample weights match oracle;
  RL-2 and RL-4 `unit_scale = NULL` vs `rep(1, n)` identical within `1e-14`
- [ ] **Replicate absolute-bounds (linear)**: RL-5 — all weights in every replicate
  column satisfy `w_k >= L_abs` and `w_k <= U_abs`
- [ ] **Replicate absolute-bounds (logit)**: RL-6 — result is `survey_replicate`;
  calibration constraint holds on full-sample weights; all base weights strictly
  inside `(L_abs, U_abs)`
- [ ] `test_invariants(result)` is first assertion in every block that produces
  a `weighted_df` or survey object
- [ ] `plans/error-messages.md` `surveywts_error_bounds_invalid_calibration`
  Condition column updated for the new logit per-unit trigger
- [ ] Test coverage ≥ 98% overall (`covr::package_coverage()`); the new `q_weights`
  resolution branch (NULL path and non-NULL path) must both be covered; absolute-bounds
  per-unit path in both functions (full-sample and replicate) must be covered
- [ ] Changelog entry written and committed on this branch

**Notes:**

- The engine fix is minimal — three `drop(x_matrix %*% lambda)` expressions gain a
  `q_weights *` prefix; the Jacobian gains a `* q_weights` factor. The resolved
  `q_weights` vector is `rep(1, n)` when `q_weights = NULL`, so arithmetic is
  unchanged for all existing callers.
- The logit calfun fix: inside both `large_pos` and `normal` branches, replace bare
  `L` / `U` with `L_sub <- if (length(L) > 1L) L[idx] else L` (and same for `U`).
  The `dF` function is element-wise and does not need modification. The final
  `pmax(L, pmin(U, f))` is already element-wise-safe.
- The absolute-bounds D6 fix for `calibrate_linear()` deletes the `scale_factor` /
  `scaled_weights` / `scaled_population` variables entirely from the bounded-absolute
  path. All that changes is: `calfun` is built with `L = abs_L / weights_vec` and
  `U = abs_U / weights_vec` (length-n vectors), and the engine receives original
  `weights_vec` and `population_totals_vec`. The engine output is then the final
  absolute-scale calibrated weights directly.
- The absolute-bounds D6 fix for `calibrate_logit()` is the same deletion pattern
  plus the new precondition: `if (!all(weights_vec > abs_L & weights_vec < abs_U))`
  → throw `surveywts_error_bounds_invalid_calibration`. The check is placed before
  the calfun is built (not inside a `tryCatch()`) so it propagates as a clean error
  rather than a replicate warning in the full-sample path. In the replicate loop the
  same check is inside the `tryCatch()` so it becomes `surveywts_warning_replicate_calibration_failed`.
- Variable `abs_L` and `abs_U` must remain in scope for the logit replicate loop;
  these are extracted from `bounds` in the full-sample path. In `calibrate_linear()`
  the replicate loop references `abs_L` and `abs_U` from the enclosing scope — verify
  these variables are declared before the replicate loop, not inside the full-sample
  `if` branch.
- Existing snapshot files in `tests/testthat/_snaps/` for `calibrate_linear` and
  `calibrate_logit` should not change — the fix is in the numeric output, not in
  any error or warning message text. Exception: if HGE-4 or HGE-5 are new error
  classes, their snapshots are created fresh. Run `testthat::snapshot_review()` only
  if a snapshot diff appears.
- For HL-10 and HG-9 ("old approach differs from new"): compute the old
  `scaled_weights = rep(1, n)` / `scaled_population = pop / mean(d)` path manually
  in the test (without calling the function) and assert `max(abs(old - new)) > 0`.
  This is a one-time regression guard.
- The `q_for_engine` variable in both callers is already computed at step 13; no
  change to that computation is needed. Only the engine call sites need
  `q_weights = q_for_engine` added.
- Run `devtools::check()` before and after the fix to confirm 0-0-≤2 throughout.
  The absolute-bounds change is a behavioral fix, not a signature change, so no
  `man/` file needs updating.
