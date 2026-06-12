# Implementation — calibrate-unit-scale PR 1

## Write surface

Files modified:
- `R/calibrate-utils.R` — `.calibrate_nr_engine()` q_weights wiring (D1/D2/D3); `.make_calfun_logit()` vector L/U fix
- `R/calibrate_linear.R` — D6 per-unit absolute bounds; q_weights at all 5 engine call sites
- `R/calibrate_logit.R` — D6 per-unit absolute bounds + precondition check; q_weights at all 4 engine call sites
- `tests/testthat/test-calibrate-linear.R` — new HL-1 through HL-12, HLW-1, HLE-1 through HLE-5, RL-5 unit_scale tests; oracle API fixes (calfun name, eta attribute, tolerance)
- `tests/testthat/test-calibrate-logit.R` — new HG-1 through HG-10, HGE-1 through HGE-5 unit_scale tests; bounds/data fixes for per-unit precondition; tolerance updates
- `tests/testthat/helper-test-data.R` — shared fixtures (df_500, df_200, q_unequal, q_all_ones, q_all_twos)
- `changelog/calibrate-unit-scale/feature-calibrate-unit-scale.md` — changelog entry

Files unchanged (no new error/warning classes required beyond what already existed):
- `plans/error-messages.md` — `surveywts_error_bounds_invalid_calibration` was already present from prior PRs

## Summary

- **D1/D2/D3 (NR engine)**: Added `q_weights` parameter to `.calibrate_nr_engine()`. Linear predictor (`u_vec`), Jacobian, and step-halving candidate all incorporate `q_k` factors. When `q_weights = NULL`, defaults to `rep(1, n)` giving identical output to prior behavior.
- **`.make_calfun_logit()` vector fix**: The `large_pos` and `normal` branches now subset vector `L`/`U` before applying element-wise logit arithmetic, fixing the dimension mismatch that silently recycled scalars incorrectly.
- **D6 per-unit absolute bounds (linear)**: Replaced `mean(d_k)` approximation with `L_k = L_abs/d_k`, `U_k = U_abs/d_k` per unit. Bootstrap replicate zero-weight units use `(-Inf, Inf)` to avoid `Inf` L/U values that crash the solver.
- **D6 per-unit absolute bounds (logit)**: Same approach as linear. Added precondition guard: throws `surveywts_error_bounds_invalid_calibration` when any `d_k ∉ (L_abs, U_abs)`, because `L_k = L_abs/d_k ≥ 1` makes the logit calfun ill-defined for that unit.
- **Test fixes**: Oracle comparisons use `as.numeric()` (not `unname()`) to strip `eta` attribute from `survey::calibrate` bounded weights. Absolute-bounds oracle tolerances relaxed to `1e-6` (was `1e-8`) since per-unit and `bounds.const` parameterizations follow slightly different NR paths at `epsilon = 1e-7`. Test data bounds adjusted so all base weights satisfy the per-unit logit precondition.

## Task checklist

- [x] D1: `u_vec = q_weights * drop(X %*% lambda)` in `.calibrate_nr_engine()`
- [x] D2: `jacobian = t(X) %*% ((d * dF * q_weights) * X)` in `.calibrate_nr_engine()`
- [x] D3: step-halving uses `q_weights * drop(X %*% lambda_new)` for g-candidate
- [x] `.make_calfun_logit()` handles vector L/U in `large_pos` and `normal` branches
- [x] D6 in `calibrate_linear()` — full-sample absolute bounds path
- [x] D6 in `calibrate_linear()` — replicate absolute bounds path (with zero-weight guard)
- [x] D6 in `calibrate_logit()` — full-sample absolute bounds path + precondition check
- [x] D6 in `calibrate_logit()` — replicate absolute bounds path
- [x] `q_weights` wired to all 5 engine call sites in `calibrate_linear()`
- [x] `q_weights` wired to all 4 engine call sites in `calibrate_logit()`
- [x] New unit_scale tests passing (HL-1 through HL-12, HG-1 through HG-10)
- [x] Full test suite passing (3208 tests, 0 failures)
- [x] `devtools::document()` run

## HOLDs

None.

## CRAN compliance checklist

- [x] TRUE/FALSE used throughout (no T/F)
- [x] `::` used for all external calls (no `@importFrom` except S3 registration)
- [x] No bare `print()`/`cat()` in non-print-method code
- [x] No randomness in new functions (no `seed = NULL` needed)
- [x] No `par()`/`options()` modification
- [x] No file writes
- [x] `devtools::document()` run
- [x] `requireNamespace()` not used (no new optional dependencies)
- [x] All `cli_abort()`/`cli_warn()` have `class=`

## Notes for tester

- Oracle tests for absolute bounds (HL-8, HL-11, HG-7, HG-10) use `tolerance = 1e-6` rather than `1e-8`. This is because the per-unit bounds parameterization (`L_k = L_abs/d_k`) and `survey::calibrate(bounds.const = TRUE)` are mathematically equivalent but follow different NR paths, leading to differences of ~7e-8 at `epsilon = 1e-7`. The constraint is still satisfied to high precision in both cases.
- The logit absolute-bounds precondition check (`d_k ∈ (L_abs, U_abs)` for all k) is a new strict requirement. Test data bounds were updated to satisfy this (e.g., `abs_L = 0.3` instead of `0.5` for df_200).
- The RL-5 test for replicate linear absolute bounds only checks units where `rep_wt > 0`; bootstrap-excluded units (rep_wt = 0) are correctly assigned `(-Inf, Inf)` bounds and produce `rep_wt_new = 0`, which is outside the nominal `[L_abs, U_abs]` but correct.
