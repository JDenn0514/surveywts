# Summarize the distribution of survey weights

Returns a tibble with summary statistics for the weight column,
optionally computed within groups defined by `by`.

## Usage

``` r
summarize_weights(x, weights = NULL, by = NULL)
```

## Arguments

- x:

  A `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob`.
  For `weighted_df` and survey objects, the weight column is
  auto-detected.

- weights:

  Bare name (NSE). Weight column. Auto-detected for `weighted_df` and
  survey objects. Required for plain `data.frame`.

- by:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Optional grouping variables. When `NULL` (default), a single-row
  summary over all observations is returned. When specified, one row is
  returned per unique group combination.

## Value

A tibble with columns `n`, `n_positive`, `n_zero`, `mean`, `cv`, `min`,
`p25`, `p50`, `p75`, `max`, `ess`. When `by` is non-`NULL`, the group
columns precede the summary columns.

## See also

Other diagnostics:
[`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md),
[`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md)

## Examples

``` r
df <- data.frame(
  group = c("A", "A", "B", "B"),
  w = c(1.2, 0.8, 1.5, 0.9)
)
summarize_weights(df, weights = w)
#> # A tibble: 1 × 11
#>       n n_positive n_zero  mean    cv   min   p25   p50   p75   max   ess
#>   <int>      <int>  <int> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#> 1     4          4      0   1.1 0.287   0.8 0.875  1.05  1.27   1.5  3.77
summarize_weights(df, weights = w, by = c(group))
#> # A tibble: 2 × 12
#>   group     n n_positive n_zero  mean    cv   min   p25   p50   p75   max   ess
#>   <chr> <int>      <int>  <int> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
#> 1 A         2          2      0   1   0.283   0.8  0.9    1    1.1    1.2  1.92
#> 2 B         2          2      0   1.2 0.354   0.9  1.05   1.2  1.35   1.5  1.88
```
