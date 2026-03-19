# Adjust survey weights for unit nonresponse

Redistributes the weights of nonrespondents to respondents within
weighting classes defined by `by`. All rows (respondents and
nonrespondents) are returned; nonrespondent weights are set to 0 and
respondent weights are adjusted upward to conserve the total weight
within each cell.

## Usage

``` r
adjust_nonresponse(
  data,
  response_status,
  weights = NULL,
  by = NULL,
  method = c("weighting-class", "propensity-cell", "propensity"),
  control = list(min_cell = 20, max_adjust = 2)
)
```

## Arguments

- data:

  A `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob`.
  Must include BOTH respondents and nonrespondents. `survey_replicate` →
  error. Any other class → error.

- response_status:

  Bare name (NSE). Binary response indicator column. Must be `logical`
  or integer `0`/`1`. `1` / `TRUE` = respondent.

- weights:

  Bare name (NSE). Weight column. `NULL` → auto-detected from
  `weighted_df` attribute or survey object `@variables$weights`. For
  plain `data.frame` with `weights = NULL`, uniform starting weights are
  used and the output column is named `".weight"`.

- by:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Weighting class variables. Redistribution is performed within each
  cell defined by the joint combination of these variables. `NULL` →
  global redistribution across all rows.

- method:

  Character scalar. Adjustment method. In Phase 0, only
  `"weighting-class"` is supported. `"propensity"` and
  `"propensity-cell"` are API-stable stubs that error until Phase 2.

- control:

  Named list of warning thresholds:

  - `min_cell`: warn when a cell has fewer than this many respondents
    (default 20, per NAEP methodology).

  - `max_adjust`: warn when the nonresponse adjustment factor for a cell
    exceeds this value (default 2.0, per
    [`survey::sparseCells()`](https://rdrr.io/pkg/survey/man/nonresponse.html)
    convention). Either condition alone triggers the warning.

## Value

All rows (respondents and nonrespondents) are returned. Nonrespondent
weights are set to 0; respondent weights are adjusted upward to conserve
the total weight within each cell.

- `data.frame` or `weighted_df` input -\> `weighted_df`

- `survey_nonprob` input -\> `survey_nonprob` (same class)

- `survey_taylor` input -\> `survey_taylor` (same class; respondent rows
  only, because `survey_taylor` does not support zero weights)

A history entry with `operation = "nonresponse_weighting_class"` is
appended to `weighting_history`.

## Details

The adjustment formula within each cell `h` is:

\$\$w\_{i,new} = w_i \times \frac{\sum w_h}{\sum w\_{h,resp}}\$\$

where \\\sum w_h\\ is the sum of all weights (respondents +
nonrespondents) in cell `h` and \\\sum w\_{h,resp}\\ is the sum of
respondent weights only.

Zero-weight observations are retained for design-based variance
estimation. Survey estimation functions (e.g.,
[`survey::svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html))
handle zero weights correctly – zero-weight units are excluded from
point estimates but included in the design structure for variance
estimation. For manual calculations, use `w[w > 0]` to exclude
nonrespondents.

Diagnostic functions
([`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md),
[`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md),
[`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md))
automatically filter to positive weights before computing statistics.

Re-calibrating post-nonresponse data requires filtering to respondents
first, because
[`calibrate()`](https://jdenn0514.github.io/surveywts/reference/calibrate.md),
[`rake()`](https://jdenn0514.github.io/surveywts/reference/rake.md), and
[`poststratify()`](https://jdenn0514.github.io/surveywts/reference/poststratify.md)
reject zero weights.

## Examples

``` r
df <- data.frame(
  age_group = c("18-34", "35-54", "55+", "18-34", "35-54"),
  responded = c(1L, 1L, 1L, 0L, 1L),
  stringsAsFactors = FALSE
)
result <- adjust_nonresponse(df, response_status = responded)
#> Warning: ! Weighting class cell "(global)" is sparse (4 respondent(s), adjustment factor
#>   1.25×).
#> ℹ Small or high-adjustment cells may produce extreme weights.
#> ℹ Consider collapsing weighting classes or adjusting `control$min_cell` /
#>   `control$max_adjust`.
```
