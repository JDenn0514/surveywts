# Package index

## Calibration

Functions for calibrating survey weights to known population totals.

- [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md)
  : Calibrate survey weights to known population totals
- [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md) :
  Rake survey weights to marginal population totals
- [`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md)
  : Post-stratify survey weights to known joint population cell totals

## Nonresponse Adjustment

Functions for adjusting survey weights for unit nonresponse.

- [`adjust_nonresponse()`](https://jdenn0514.github.io/surveywts/reference/adjust_nonresponse.md)
  : Adjust survey weights for unit nonresponse

## Replicate Weights

Functions for creating replicate weights for variance estimation.

- [`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md)
  : Create bootstrap replicate weights
- [`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md)
  : Create jackknife replicate weights
- [`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md)
  : Create BRR (Fay) replicate weights
- [`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md)
  : Create generalized bootstrap replicate weights
- [`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md)
  : Create generalized replication replicate weights
- [`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
  : Create successive difference replication (SDR) weights
- [`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md)
  : Create replicate weights (dispatcher)
- [`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md)
  : Convert a replicate design back to a Taylor design

## Diagnostics

Functions for assessing the distribution and quality of survey weights.

- [`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md)
  : Kish's effective sample size
- [`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md)
  : Coefficient of variation of survey weights
- [`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md)
  : Summarize the distribution of survey weights
