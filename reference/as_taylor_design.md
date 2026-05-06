# Convert a replicate design back to a Taylor design

Reconstructs a `survey_taylor` from a `survey_replicate` created by
`create_*_weights()`. The original Taylor structure (PSU IDs, strata,
FPC, nest flag) is read from the `"replicate_creation"` entry in the
weighting history. Replicate weight columns are dropped from `@data`.

## Usage

``` r
as_taylor_design(data)
```

## Arguments

- data:

  A `survey_replicate` created by `create_*_weights()`, or a
  `survey_taylor` (returns unchanged with a warning).

## Value

A `survey_taylor`.

## Details

Returns `data` unchanged (with a warning) if `data` is already a
`survey_taylor`.

## See also

Other replicate-weights:
[`create_bootstrap_weights()`](https://jdenn0514.github.io/surveywts/reference/create_bootstrap_weights.md),
[`create_brr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_brr_weights.md),
[`create_gen_boot_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_boot_weights.md),
[`create_gen_rep_weights()`](https://jdenn0514.github.io/surveywts/reference/create_gen_rep_weights.md),
[`create_jackknife_weights()`](https://jdenn0514.github.io/surveywts/reference/create_jackknife_weights.md),
[`create_replicate_weights()`](https://jdenn0514.github.io/surveywts/reference/create_replicate_weights.md),
[`create_sdr_weights()`](https://jdenn0514.github.io/surveywts/reference/create_sdr_weights.md)
