# Create BRR (Fay) replicate weights

Generates balanced repeated replication (BRR) or Fay's BRR replicate
weights via
[`survey::as.svrepdesign()`](https://rdrr.io/pkg/survey/man/as.svrepdesign.html).
Requires a paired-PSU design (exactly 2 PSUs per stratum).

## Usage

``` r
create_brr_weights(data, ..., rho = 0, mse = TRUE)
```

## Arguments

- data:

  A `survey_taylor` with exactly 2 PSUs per stratum.

- ...:

  Must be empty.

- rho:

  `numeric(1)`, default `0`. Fay damping coefficient. `rho = 0` gives
  standard BRR; `rho > 0` gives Fay's BRR variant with factors `rho` and
  `2 - rho`. Must satisfy `0 <= rho < 1`.

- mse:

  `logical(1)`, default `TRUE`.

## Value

A `survey_replicate` with `@variables$type` of `"BRR"` or `"Fay"`.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
