# Create bootstrap replicate weights

Generates bootstrap replicate weights via
[`svrep::as_bootstrap_design()`](https://bschneidr.github.io/svrep/reference/as_bootstrap_design.html).
Both `survey_taylor` and `survey_nonprob` inputs are supported.

## Usage

``` r
create_bootstrap_weights(
  data,
  replicates = 500L,
  ...,
  type = c("Rao-Wu-Yue-Beaumont", "Rao-Wu", "Antal-Tille", "Preston", "Canty-Davison"),
  mse = TRUE,
  seed = NULL
)
```

## Arguments

- data:

  A `survey_taylor` or `survey_nonprob` design object.

- replicates:

  `integer(1)`, default `500L`. Number of bootstrap replicates. Must be
  \>= 2. Whole-number doubles are coerced silently.

- ...:

  Must be empty. Forces all subsequent arguments to be named.

- type:

  `character(1)`. Bootstrap variant passed to
  [`svrep::as_bootstrap_design()`](https://bschneidr.github.io/svrep/reference/as_bootstrap_design.html).
  One of `"Rao-Wu-Yue-Beaumont"` (default), `"Rao-Wu"`, `"Antal-Tille"`,
  `"Preston"`, or `"Canty-Davison"`.

- mse:

  `logical(1)`, default `TRUE`. If `TRUE`, variance is estimated as the
  deviation from the full-sample estimate.

- seed:

  `integer(1)` or `NULL`. If non-`NULL`, sets the RNG seed via
  [`withr::local_seed()`](https://withr.r-lib.org/reference/with_seed.html)
  for the duration of the call; caller's RNG state is restored on exit.

## Value

A `survey_replicate` with `replicates` new `rep_1...rep_N` columns,
`@variables$type = "bootstrap"`, and a `"replicate_creation"` entry in
the weighting history.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
