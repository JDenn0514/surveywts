# Changelog — feature/calibrate-rake-nr

## Changed

- `calibrate_rake()`: renamed algorithm `"anesrake"` to `"classic_ipf"` (IPF = iterative proportional fitting). The algorithm is unchanged; only the name is updated. Code passing `algorithm = "anesrake"` must be updated to `algorithm = "classic_ipf"`.
- `calibrate_rake()`: removed algorithm `"survey"`. Unknown algorithm values now trigger an `rlang::arg_match()` error.
- `calibrate()`: `method` argument changed from `c("greg", "rake", "poststrat")` (default `"greg"`) to `c("rake", "linear", "logit")` (default `"rake"`). Dispatches to `calibrate_rake()`, `calibrate_linear()`, and `calibrate_logit()` respectively.

## Added

- `calibrate_rake()`: new `algorithm = "nr"` option for Newton-Raphson raking (Deville & Sarndal 1993). Uses the exponential calibration function F(u) = exp(u) via the shared `.calibrate_nr_engine()`. Stores the converged `eta` vector as `@calibration$lambda`. The `cap` argument is not supported with `algorithm = "nr"` and raises `surveywts_error_cap_not_supported_nr`.
- `calibrate_rake()`: warns with `surveywts_warning_control_param_ignored` when `control` keys specific to one algorithm are supplied with the other algorithm (e.g., `pval` with `algorithm = "nr"`, or `epsilon` with `algorithm = "classic_ipf"`).

## Removed

- `calibrate_greg()` exported function deleted. Use `calibrate_linear()` (for linear/truncated-linear GREG calibration) instead.
