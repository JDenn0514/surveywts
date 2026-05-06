# Create generalized bootstrap replicate weights

Generates generalized bootstrap replicate weights via
[`svrep::as_gen_boot_design()`](https://bschneidr.github.io/svrep/reference/as_gen_boot_design.html).
Requires a `survey_taylor` design.

## Usage

``` r
create_gen_boot_weights(
  data,
  replicates = 500L,
  ...,
  variance_estimator = "SD1",
  tau = 1,
  aux_var_names = NULL,
  mse = TRUE,
  seed = NULL
)
```

## Arguments

- data:

  A `survey_taylor` design.

- replicates:

  `integer(1)`, default `500L`. Number of bootstrap replicates.

- ...:

  Must be empty.

- variance_estimator:

  `character(1)`. Target variance estimator. One of `"SD1"` (default),
  `"SD2"`, `"Horvitz-Thompson"`, `"Yates-Grundy"`,
  `"Poisson Horvitz-Thompson"`, `"Stratified Multistage SRS"`,
  `"Ultimate Cluster"`, `"Deville-1"`, `"Deville-2"`, `"Deville-Tille"`,
  `"BOSB"`, or `"Beaumont-Emond"`.

- tau:

  `numeric(1)` or `"auto"`, default `1`. Rescaling constant to prevent
  negative replicate weights.

- aux_var_names:

  \<[`tidy-select`](https://tidyselect.r-lib.org/reference/language.html)\>
  or `NULL`. Auxiliary variable columns. Required when
  `variance_estimator = "Deville-Tille"`.

- mse:

  `logical(1)`, default `TRUE`.

- seed:

  `integer(1)` or `NULL`. RNG seed.

## Value

A `survey_replicate` with `@variables$type = "bootstrap"`.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
