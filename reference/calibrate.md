# Calibrate survey weights to known population totals

Adjusts survey weights so that the weighted marginal totals match known
population values. Supports linear (GREG) and logit calibration methods
for categorical auxiliary variables.

## Usage

``` r
calibrate(
  data,
  variables,
  population,
  weights = NULL,
  wt_name = "wts",
  method = c("linear", "logit"),
  type = c("prop", "count"),
  control = list(maxit = 50, epsilon = 1e-07)
)
```

## Arguments

- data:

  A `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob`.
  `survey_replicate` → error. Any other class → error.

- variables:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Columns to calibrate on. Must be categorical (character or factor).
  Specify as a bare name or `c(var1, var2, ...)`.

- population:

  Named list of population targets. Names must match the column names
  selected by `variables`. Each element: a named numeric vector
  `c(level = target, ...)`.

  For `type = "prop"`: values must sum to 1.0 (within `1e-6` tolerance).
  For `type = "count"`: values must be strictly positive.

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Weight column name (bare name). `NULL` → auto-detected from
  `weighted_df` attribute or survey object `@variables$weights`. For
  plain `data.frame` with `weights = NULL`, uniform starting weights are
  used and the output column is named by `wt_name` (default `"wts"`).

- wt_name:

  Character scalar. Name of the output weight column in the returned
  `weighted_df`. Default `"wts"`. Ignored when `data` is a survey object
  (`survey_taylor` or `survey_nonprob`).

- method:

  Character scalar. `"linear"` (default): one-step exact GREG
  calibration (may produce negative weights). `"logit"`: bounded
  iterative calibration (always positive).

- type:

  Character scalar. `"prop"` (default): `population` values are
  proportions. `"count"`: `population` values are counts.

- control:

  Named list of convergence parameters. Merged with defaults
  `list(maxit = 50, epsilon = 1e-7)` — omitted keys retain their
  defaults.

## Value

- `data.frame` or `weighted_df` input → `weighted_df`

- `survey_taylor` or `survey_nonprob` input → same class as input
  (`survey_taylor` or `survey_nonprob`; class is preserved)

The weight column in the output contains calibrated weights. A history
entry with `operation = "calibration"` is appended to
`weighting_history`.

## See also

Other calibration:
[`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md),
[`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md)

## Examples

``` r
df <- data.frame(
  age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
  sex = c("M", "F", "M", "F", "M"),
  stringsAsFactors = FALSE
)
pop <- list(
  age_group = c("18-34" = 0.30, "35-54" = 0.40, "55+" = 0.30),
  sex = c("M" = 0.48, "F" = 0.52)
)
result <- calibrate(df, variables = c(age_group, sex), population = pop)
```
