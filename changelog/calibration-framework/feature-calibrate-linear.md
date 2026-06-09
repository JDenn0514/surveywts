# Changelog — feature/calibrate-linear

## Added

- `calibrate_linear()`: new exported function for linear (GREG) and truncated-linear calibration following Deville & Sarndal (1992). Accepts `data.frame`, `weighted_df`, `survey_taylor`, `survey_nonprob`, and `survey_replicate` inputs. Supports `type = "prop"` and `type = "count"`, optional bounds (`bounds_scale = "multiplicative"` or `"absolute"`), and unit-specific scaling via `unit_scale`. Stores full calibration provenance in `@calibration` slot. Oracle-tested against `survey::calibrate()` within 1e-8.
