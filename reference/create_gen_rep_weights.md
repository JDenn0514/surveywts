# Create generalized replication replicate weights

Generates Fay's generalized replication weights via
[`svrep::as_fays_gen_rep_design()`](https://bschneidr.github.io/svrep/reference/as_fays_gen_rep_design.html).
Produces deterministic replicate weights (no randomness). Requires a
`survey_taylor` design.

## Usage

``` r
create_gen_rep_weights(
  data,
  ...,
  variance_estimator = "SD2",
  max_replicates = Inf,
  balanced = TRUE,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
)
```

## Arguments

- data:

  A `survey_taylor` design.

- ...:

  Must be empty.

- variance_estimator:

  `character(1)`. Target variance estimator. Same options as
  [`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md).
  Default `"SD2"`.

- max_replicates:

  `numeric(1)`, default `Inf`. Maximum number of replicates; `Inf` uses
  the natural count.

- balanced:

  `logical(1)`, default `TRUE`. Equal contribution of replicates to
  variance estimates.

- aux_var_names:

  `<tidy-select>` or `NULL`. Required for `"Deville-Tille"`.

- mse:

  `logical(1)`, default `TRUE`.

- seed:

  `integer(1)` or `NULL`. RNG seed for reproducibility.

## Value

A `survey_replicate` with generalized replication weights.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
