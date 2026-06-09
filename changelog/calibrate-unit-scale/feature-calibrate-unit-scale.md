# Changelog — feature/calibrate-unit-scale

## Fixed

- `.calibrate_nr_engine()` (in `calibrate-utils.R`): Added `q_weights` parameter. The Newton-Raphson engine now correctly incorporates unit-specific scaling factors (D1: linear predictor, D2: Jacobian, D3: step-halving candidate check) following Deville & Sarndal (1992). When `unit_scale = NULL`, behavior is numerically identical to the pre-fix implementation.

- `.make_calfun_logit()` (in `calibrate-utils.R`): Fixed dimension mismatch when `L` and `U` are vectors. The `large_pos` and `normal` branches now subset `L` and `U` by index before applying the logit formula, preventing incorrect recycling.

- `calibrate_linear()`: D6 fix — absolute bounds now use per-unit multiplicative bounds `L_k = L_abs / d_k` and `U_k = U_abs / d_k` instead of the previous `mean(d_k)` approximation. Zero-weight replicate units get `(-Inf, Inf)` bounds to avoid division by zero. Wired `unit_scale` to all five engine call sites (full-sample unbounded, full-sample multiplicative, full-sample absolute, replicate multiplicative, replicate absolute).

- `calibrate_logit()`: Same D6 per-unit absolute-bounds fix as linear. Added precondition check: throws `surveywts_error_bounds_invalid_calibration` if any base weight falls outside `(L_abs, U_abs)`, since the logit calfun is ill-defined in that case. Wired `unit_scale` to all four engine call sites (full-sample multiplicative, full-sample absolute, replicate multiplicative, replicate absolute).
