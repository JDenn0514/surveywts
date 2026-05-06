# Create jackknife replicate weights

Generates jackknife replicate weights via
[`survey::as.svrepdesign()`](https://rdrr.io/pkg/survey/man/as.svrepdesign.html)
(for delete-1) or
[`svrep::as_random_group_jackknife_design()`](https://bschneidr.github.io/svrep/reference/as_random_group_jackknife_design.html)
(for random-groups).

## Usage

``` r
create_jackknife_weights(
  data,
  replicates = NULL,
  ...,
  type = c("delete-1", "random-groups"),
  mse = TRUE,
  seed = NULL
)
```

## Arguments

- data:

  A `survey_taylor` or `survey_nonprob` design. `survey_nonprob`
  supports `type = "delete-1"` only.

- replicates:

  `integer(1)` or `NULL`. Number of random groups when
  `type = "random-groups"`. Required for random-groups; ignored for
  delete-1.

- ...:

  Must be empty.

- type:

  `character(1)`. `"delete-1"` (default): one replicate per PSU,
  auto-selecting JK1 (unstratified) or JKn (stratified).
  `"random-groups"`: PSUs randomly divided into `replicates` groups.

- mse:

  `logical(1)`, default `TRUE`.

- seed:

  `integer(1)` or `NULL`. RNG seed for random-group assignment (ignored
  for delete-1).

## Value

A `survey_replicate` with `@variables$type` of `"JK1"` or `"JKn"`.

## See also

Other replicate-weights:
[`as_taylor_design()`](https://jdenn0514.github.io/surveywts/reference/as_taylor_design.md),
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
