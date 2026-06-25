# trim_weights() rejects list input

    Code
      trim_weights(list(x = 1:5))
    Condition
      Error in `.check_weight_utils_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <list>.
      v See package documentation for supported input types.

# trim_weights() rejects 0-row data frame

    Code
      trim_weights(empty, weights = w)
    Condition
      Error in `trim_weights()`:
      x `data` has 0 rows.
      i Weight trimming requires at least one observation.

# trim_weights() rejects missing weight column

    Code
      trim_weights(df, weights = missing_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column missing_col not found in `data`.
      i Available columns: x.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# trim_weights() rejects non-numeric weight column

    Code
      trim_weights(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w must be numeric.
      i Got <character>.
      v Use `as.numeric(w)` to convert.

# trim_weights() rejects negative weight values

    Code
      trim_weights(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# trim_weights() rejects NA weight values

    Code
      trim_weights(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# trim_weights() rejects upper = NULL with type = 'percentile'

    Code
      trim_weights(df, weights = base_weight, type = "percentile")
    Condition
      Error in `trim_weights()`:
      x `upper` must be specified when `type = "percentile"`.
      i `upper = NULL` is only valid when `type = "absolute"`.
      v Provide an explicit `upper` value in [0, 1], e.g. `upper = 0.99`.

# trim_weights() rejects k = character scalar

    Code
      trim_weights(df, weights = base_weight, k = "5")
    Condition
      Error in `trim_weights()`:
      x `k` must be a single numeric value, not `NA`.
      i Got <character> of length 1.

# trim_weights() rejects k = NA_real_

    Code
      trim_weights(df, weights = base_weight, k = NA_real_)
    Condition
      Error in `trim_weights()`:
      x `k` must be a single numeric value, not `NA`.
      i Got <numeric> of length 1.

# trim_weights() rejects k = length-2 numeric

    Code
      trim_weights(df, weights = base_weight, k = c(1, 2))
    Condition
      Error in `trim_weights()`:
      x `k` must be a single numeric value, not `NA`.
      i Got <numeric> of length 2.

# trim_weights() rejects k = -1

    Code
      trim_weights(df, weights = base_weight, k = -1)
    Condition
      Error in `trim_weights()`:
      x `k` must be positive.
      i Got -1.
      v Use a positive IQR multiplier, e.g. `k = 5`.

# trim_weights() rejects k = 0

    Code
      trim_weights(df, weights = base_weight, k = 0)
    Condition
      Error in `trim_weights()`:
      x `k` must be positive.
      i Got 0.
      v Use a positive IQR multiplier, e.g. `k = 5`.

# trim_weights() rejects lower = character scalar

    Code
      trim_weights(df, weights = base_weight, lower = "0.5")
    Condition
      Error in `trim_weights()`:
      x `lower` must be a single numeric value, not `NA`.
      i Got <character> of length 1.

# trim_weights() rejects lower = NA_real_

    Code
      trim_weights(df, weights = base_weight, lower = NA_real_)
    Condition
      Error in `trim_weights()`:
      x `lower` must be a single numeric value, not `NA`.
      i Got <numeric> of length 1.

# trim_weights() rejects upper = length-2 numeric

    Code
      trim_weights(df, weights = base_weight, upper = c(1, 2))
    Condition
      Error in `trim_weights()`:
      x `upper` must be a single numeric value, not `NA`.
      i Got <numeric> of length 2.

# trim_weights() rejects upper = NA_real_

    Code
      trim_weights(df, weights = base_weight, upper = NA_real_)
    Condition
      Error in `trim_weights()`:
      x `upper` must be a single numeric value, not `NA`.
      i Got <numeric> of length 1.

# trim_weights() rejects equal resolved bounds (lower = upper)

    Code
      trim_weights(df, weights = base_weight, lower = 3, upper = 3)
    Condition
      Error in `trim_weights()`:
      x Resolved lower bound (3) must be strictly less than upper bound (3).
      i Bounds must satisfy `lower_abs < upper_abs`.
      v Adjust `lower` and `upper` so that the lower bound is smaller.

# trim_weights() rejects reversed bounds (lower > upper)

    Code
      trim_weights(df, weights = base_weight, lower = 5, upper = 3)
    Condition
      Error in `trim_weights()`:
      x Resolved lower bound (5) must be strictly less than upper bound (3).
      i Bounds must satisfy `lower_abs < upper_abs`.
      v Adjust `lower` and `upper` so that the lower bound is smaller.

# trim_weights() rejects reversed percentile bounds

    Code
      trim_weights(df, weights = base_weight, lower = 0.99, upper = 0.01, type = "percentile")
    Condition
      Error in `trim_weights()`:
      x Resolved lower bound (2.40144211600576) must be strictly less than upper bound (0.430299784651373).
      i Bounds must satisfy `lower_abs < upper_abs`.
      v Adjust `lower` and `upper` so that the lower bound is smaller.

# trim_weights() rejects upper = 0 (absolute, non-positive)

    Code
      trim_weights(df, weights = base_weight, upper = 0)
    Condition
      Error in `trim_weights()`:
      x `upper` must be strictly positive when `type = "absolute"`.
      i Got 0.
      v Provide a positive upper bound.

# trim_weights() rejects upper = -1 (absolute, negative)

    Code
      trim_weights(df, weights = base_weight, upper = -1)
    Condition
      Error in `trim_weights()`:
      x `upper` must be strictly positive when `type = "absolute"`.
      i Got -1.
      v Provide a positive upper bound.

# trim_weights() rejects lower = -0.1 with type = 'percentile'

    Code
      trim_weights(df, weights = base_weight, lower = -0.1, upper = 0.99, type = "percentile")
    Condition
      Error in `trim_weights()`:
      x `lower` must be in [0, 1] when `type = "percentile"`.
      i Got -0.1.

# trim_weights() rejects upper = 1.1 with type = 'percentile'

    Code
      trim_weights(df, weights = base_weight, upper = 1.1, type = "percentile")
    Condition
      Error in `trim_weights()`:
      x `upper` must be in [0, 1] when `type = "percentile"`.
      i Got 1.1.

# trim_weights() rejects wt_name = 1L (plain df + NULL weights)

    Code
      trim_weights(df, wt_name = 1L)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <integer> of length 1.

# trim_weights() rejects wt_name = '' (plain df + NULL weights)

    Code
      trim_weights(df, wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# rescale_weights() rejects list input

    Code
      rescale_weights(list(x = 1:5))
    Condition
      Error in `.check_weight_utils_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <list>.
      v See package documentation for supported input types.

# rescale_weights() rejects 0-row data frame

    Code
      rescale_weights(empty, weights = w)
    Condition
      Error in `rescale_weights()`:
      x `data` has 0 rows.
      i Weight rescaling requires at least one observation.

# rescale_weights() rejects missing weight column

    Code
      rescale_weights(df, weights = missing_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column missing_col not found in `data`.
      i Available columns: x.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# rescale_weights() rejects non-numeric weight column

    Code
      rescale_weights(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w must be numeric.
      i Got <character>.
      v Use `as.numeric(w)` to convert.

# rescale_weights() rejects negative weight values

    Code
      rescale_weights(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# rescale_weights() rejects NA weight values

    Code
      rescale_weights(df, weights = w)
    Condition
      Error in `.validate_weights()`:
      x Weight column w contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# rescale_weights() rejects by variable not in data

    Code
      rescale_weights(df, weights = base_weight, by = nonexistent_col)
    Condition
      Error in `value[[3L]]()`:
      x `by` variable nonexistent_col not found in `data`.
      i Can't select columns that don't exist. x Column `nonexistent_col` doesn't exist.
      v Check that all grouping variables exist as columns in `data`.

# rescale_weights() rejects by variable with NA values

    Code
      rescale_weights(df, weights = base_weight, by = age_group)
    Condition
      Error in `rescale_weights()`:
      x `by` variable age_group contains 1 NA value(s).
      i Grouping variables must be fully observed.
      v Remove rows with missing age_group before calling `rescale_weights()`.

# rescale_weights() rejects wt_name = 1L (plain df + NULL weights)

    Code
      rescale_weights(df, wt_name = 1L)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <integer> of length 1.

# rescale_weights() rejects wt_name = '' (plain df + NULL weights)

    Code
      rescale_weights(df, wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

