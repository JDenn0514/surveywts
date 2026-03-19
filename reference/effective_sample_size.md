# Kish's effective sample size

Computes the effective sample size using Kish's formula: \$\$ESS =
\frac{(\sum w)^2}{\sum w^2}\$\$

## Usage

``` r
effective_sample_size(x, weights = NULL)
```

## Arguments

- x:

  A `data.frame`, `weighted_df`, `survey_taylor`, or `survey_nonprob`.
  For `weighted_df` and survey objects, the weight column is
  auto-detected.

- weights:

  Bare name (NSE). Weight column. Auto-detected for `weighted_df` and
  survey objects. Required for plain `data.frame`.

## Value

A named numeric scalar: `c(n_eff = <value>)`. The name `"n_eff"` is part
of the API contract.

## See also

Other diagnostics:
[`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md),
[`weight_variability()`](https://jdenn0514.github.io/surveywts/reference/weight_variability.md)

## Examples

``` r
df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))
effective_sample_size(df, weights = w)
#>   n_eff 
#> 4.76378 
```
