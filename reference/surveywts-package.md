# Tools for Survey Weighting and Calibration

Provides tools for calibrating survey weights to known population totals
using GREG, raking (iterative proportional fitting), and
post-stratification. Supports nonresponse adjustment via the
weighting-class method, effective sample size diagnostics, and full
weighting history tracking for reproducible survey analysis workflows.

## Key Functions

**Calibration:**

- [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md)
  — GREG (linear) or logit calibration to population totals

- [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md) —
  raking via iterative proportional fitting

- [`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md)
  — exact post-stratification to cell counts or proportions

**Nonresponse:**

- [`adjust_nonresponse()`](https://jdenn0514.github.io/surveywts/reference/adjust_nonresponse.md)
  — weighting-class nonresponse adjustment

**Diagnostics:**

- [`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md)
  — Kish effective sample size

- [`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md)
  — coefficient of variation of weights

- [`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md)
  — full weight distribution summary table

## See also

Useful links:

- <https://github.com/JDenn0514/surveywts>

- <https://jdenn0514.github.io/surveywts/>

- Report bugs at <https://github.com/JDenn0514/surveywts/issues>

## Author

**Maintainer**: Jacob Dennen <jdenn0514@gmail.com>
([ORCID](https://orcid.org/0000-0003-3006-7364)) \[copyright holder\]
