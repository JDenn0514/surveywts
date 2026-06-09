# Changelog — feature/calibrate-logit

## Added

- `calibrate_logit()`: new exported function for logit-bounded calibration following Deville, Sarndal & Sautory (1993). Accepts `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`, and `survey_replicate` inputs. Supports `type = "prop"` and `type = "count"`, mandatory `bounds` constraining g-weights to the open interval `(L, U)`, `bounds_scale = "multiplicative"` (default) or `"absolute"`, and unit-specific scaling via `unit_scale`. Guarantees strictly positive calibrated weights by construction. Stores full calibration provenance including the converged Newton-Raphson `lambda` vector in the `@calibration` slot. Oracle-tested against `survey::calibrate(calfun = "logit")` within 1e-8.
