# Coefficient of variation of survey weights

Computes the coefficient of variation (CV) of the weight column: \$\$CV
= \frac{sd(w)}{mean(w)}\$\$

## Usage

``` r
weight_variability(x, weights = NULL)
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

A named numeric scalar: `c(cv = <value>)`. The name `"cv"` is part of
the API contract.

## See also

Other diagnostics:
[`effective_sample_size()`](https://jdenn0514.github.io/surveywts/reference/effective_sample_size.md),
[`summarize_weights()`](https://jdenn0514.github.io/surveywts/reference/summarize_weights.md)

## Examples

``` r
df <- data.frame(x = 1:5, w = c(1.2, 0.8, 1.5, 0.9, 1.1))
weight_variability(df, weights = w)
#>        cv 
#> 0.2489648 
```
