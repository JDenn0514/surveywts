# Post-stratify survey weights to known joint population cell totals

Adjusts survey weights so that the weighted cell counts (or proportions)
match known population values for every joint combination of
stratification variables. Unlike
[`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md)
and [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md),
which match marginal totals, `poststratify()` matches exact
cross-tabulation cells in a single pass.

## Usage

``` r
poststratify(
  data,
  strata,
  population,
  weights = NULL,
  wt_name = "wts",
  type = c("prop", "count")
)
```

## Arguments

- data:

  A `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob`.
  `survey_replicate` -\> error. Any other class -\> error.

- strata:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Stratification variables that jointly define the cells. Specify as a
  bare name or `c(var1, var2, ...)`. Unlike
  [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md)
  and
  [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md),
  strata variables may be any type (character, factor, integer,
  numeric).

- population:

  A `data.frame` with one column per variable selected by `strata`
  (column names must match exactly), one column named `"target"`, and
  one row per unique cell combination.

  For `type = "count"`: values in `target` must be strictly positive.
  For `type = "prop"`: values in `target` must sum to 1.0 (within
  `1e-6`).

- weights:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Weight column name (bare name). `NULL` -\> auto-detected from
  `weighted_df` attribute or survey object `@variables$weights`. For
  plain `data.frame` with `weights = NULL`, uniform starting weights are
  used.

- wt_name:

  Character scalar. Name of the output weight column in the returned
  `weighted_df`. Default `"wts"`. Ignored when `data` is a survey object
  (`survey_taylor` or `survey_nonprob`).

- type:

  Character scalar. `"prop"` (default): `target` values are proportions
  summing to 1.0. `"count"`: `target` values are population counts.
  Consistent with
  [`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md)
  and
  [`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md).

## Value

- `data.frame` or `weighted_df` input -\> `weighted_df`

- `survey_taylor` or `survey_nonprob` input -\> same class as input
  (`survey_taylor` or `survey_nonprob`; class is preserved)

The weight column in the output contains post-stratified weights. A
history entry with `operation = "poststratify"` is appended to
`weighting_history`.

## See also

Other calibration:
[`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md),
[`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md)

## Examples

``` r
df <- data.frame(
  age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
  sex = c("M", "M", "M", "F", "F", "F"),
  stringsAsFactors = FALSE
)

# Proportion targets (default type = "prop")
pop_prop <- data.frame(
  age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
  sex = c("M", "M", "M", "F", "F", "F"),
  target = c(0.14, 0.18, 0.17, 0.15, 0.19, 0.17)
)
result <- poststratify(df, strata = c(age_group, sex), population = pop_prop)

# Count targets (explicit type = "count")
pop_count <- data.frame(
  age_group = c("18-34", "35-54", "55+", "18-34", "35-54", "55+"),
  sex = c("M", "M", "M", "F", "F", "F"),
  target = c(14000, 18000, 17000, 15000, 19000, 17000)
)
result2 <- poststratify(df, strata = c(age_group, sex),
  population = pop_count, type = "count")
```
