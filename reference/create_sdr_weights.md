# Create successive difference replication (SDR) weights

Generates successive difference replication weights via
[`svrep::as_sdr_design()`](https://bschneidr.github.io/svrep/reference/as_sdr_design.html).
Requires a `survey_taylor` design.

## Usage

``` r
create_sdr_weights(data, replicates = 100L, ..., sort_var = NULL, mse = TRUE)
```

## Arguments

- data:

  A `survey_taylor` design. PSUs should be in systematic selection
  order, or use `sort_var`.

- replicates:

  `integer(1)`, default `100L`. Target replicate count (\>= 4). Actual
  count may be slightly larger due to Hadamard matrix sizing.

- ...:

  Must be empty.

- sort_var:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  Bare column name giving the systematic selection order. Required for
  stratified designs (svrep \>= 0.9.1); for non-stratified designs row
  order is used as fallback.

- mse:

  `logical(1)`, default `TRUE`.

## Value

A `survey_replicate` with `@variables$type = "successive-difference"`.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md)
