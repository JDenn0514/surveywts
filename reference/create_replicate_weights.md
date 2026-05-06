# Create replicate weights (dispatcher)

Dispatches to the appropriate `create_*_weights()` function based on
`method`. All validation, defaults, and error messages are handled by
the dispatched function; this function only resolves the method name.

## Usage

``` r
create_replicate_weights(
  data,
  method = c("bootstrap", "jackknife", "brr", "generalized-bootstrap",
    "generalized-replicate", "successive-difference"),
  ...
)
```

## Arguments

- data:

  A `survey_taylor` or `survey_nonprob` design.

- method:

  `character(1)`. One of `"bootstrap"`, `"jackknife"`, `"brr"`,
  `"generalized-bootstrap"`, `"generalized-replicate"`,
  `"successive-difference"`.

- ...:

  Passed as-is to the dispatched function. Invalid arguments for the
  selected method produce R's native "unused argument" error.

## Value

A `survey_replicate`.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
