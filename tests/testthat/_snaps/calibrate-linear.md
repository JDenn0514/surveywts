# E1: calibrate_linear() throws surveywts_error_unsupported_class for bad input

    Code
      calibrate_linear(list(x = 1:3), targets = list())
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <list>.
      v See package documentation for supported input types.

# E2: calibrate_linear() throws surveywts_error_empty_data for 0-row input

    Code
      calibrate_linear(empty_df, targets = targets, weights = base_weight)
    Condition
      Error in `calibrate_linear()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# E3: calibrate_linear() throws surveywts_error_wt_name_not_scalar

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, wt_name = c("a",
        "b"))
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <character> of length 2.

# E4: calibrate_linear() throws surveywts_error_wt_name_empty for NA wt_name

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, wt_name = NA_character_)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# E5: calibrate_linear() throws surveywts_error_reference_design_not_taylor

    Code
      calibrate_linear(df, targets = targets, weights = base_weight,
        reference_design = "not_a_design")
    Condition
      Error in `.validate_reference_design()`:
      x `reference_design` must be a <survey_taylor>.
      i Got class <character>.
      v Pass the <survey_taylor> object used to compute the targets.

# E6: calibrate_linear() throws surveywts_error_weights_not_found

    Code
      calibrate_linear(df, targets = targets, weights = nonexistent_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column nonexistent_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, and base_weight.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# E7: calibrate_linear() throws surveywts_error_weights_not_numeric

    Code
      calibrate_linear(df, targets = targets, weights = bad_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column bad_wt must be numeric.
      i Got <character>.
      v Use `as.numeric(bad_wt)` to convert.

# E8: calibrate_linear() throws surveywts_error_weights_nonpositive

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# E9: calibrate_linear() throws surveywts_error_weights_na

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# E10: calibrate_linear() throws surveywts_error_targets_variable_not_found

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `calibrate_linear()`:
      x Target variable nonexistent_var not found in `data`.
      i Names in `targets` must match column names in `data`.
      v Check spelling: available columns are id, age_group, sex, education, region, and base_weight.

# E11: calibrate_linear() throws surveywts_error_variable_not_categorical

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable id is <integer>.
      i Currently only categorical (character or factor) variables are supported.
      v Convert to factor or character. Continuous auxiliary variable calibration is not currently supported.

# E12: calibrate_linear() throws surveywts_error_variable_has_na

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable age_group contains 1 NA value(s).
      i NA values in calibration variables are not allowed.
      v Remove or impute NA values in age_group before calling `calibrate_greg()`.

# E13: calibrate_linear() throws surveywts_error_population_level_missing

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "55+" of variable age_group is present in `data` but not in `targets`.
      i Every level in the data must have a corresponding population target.
      v Add "55+" to the age_group entry in `targets`.

# E14: calibrate_linear() throws surveywts_error_population_level_extra

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "65+" of variable age_group is present in `targets` but not in `data`.
      i Population targets for levels absent from the sample are undefined.
      v Remove "65+" from the age_group entry in `targets`.

# E15: calibrate_linear() throws surveywts_error_population_totals_invalid (prop != 1)

    Code
      calibrate_linear(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 1.2, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `targets$age_group`.

# E16: calibrate_linear() throws surveywts_error_population_totals_invalid (count <= 0)

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, type = "count")
    Condition
      Error in `.validate_population_marginals()`:
      x Population targets for age_group contain 1 non-positive value(s).
      i When `type = "count"`, all targets must be strictly positive (> 0).
      v Remove or correct non-positive entries in `targets$age_group`.

# E17: calibrate_linear() throws surveywts_error_margins_format_invalid for bad targets

    Code
      calibrate_linear(df, targets = 42, weights = base_weight)
    Condition
      Error in `.parse_margins()`:
      x `targets` must be a named list or a data frame with columns variable, level, and target.
      i Got <numeric>.
      v See `calibrate_rake()`, `calibrate_linear()`, or `calibrate_logit()` documentation for accepted formats.

# E18: calibrate_linear() throws surveywts_error_bounds_invalid_calibration (L >= 1)

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(1, 3))
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "multiplicative"`, the lower bound `L` must be strictly less than 1.
      i Got `L = 1`.
      v Supply `bounds = c(L, U)` where `L < 1 < U`, e.g. `c(0.5, 2)`.

# E19: calibrate_linear() throws surveywts_error_bounds_invalid_calibration (U <= 1)

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(0.3,
        0.9))
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "multiplicative"`, the upper bound `U` must be strictly greater than 1.
      i Got `U = 0.9`.
      v Supply `bounds = c(L, U)` where `L < 1 < U`, e.g. `c(0.5, 2)`.

# E20: calibrate_linear() throws surveywts_error_unit_scale_invalid (not numeric)

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, unit_scale = rep(
        "1", nrow(df)))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 50.

# calibrate_linear() throws surveywts_error_bounds_invalid_calibration for bounds length != 2

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(0.5,
        2, 3))
    Condition
      Error in `.validate_bounds()`:
      x `bounds` must be a numeric vector of length 2.
      i Got length 3.
      v Supply `bounds = c(L, U)` where `L < 1 < U`.

# calibrate_linear() throws surveywts_error_bounds_invalid_calibration for bounds with NA

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(NA, 2))
    Condition
      Error in `.validate_bounds()`:
      x `bounds` must not contain `NA` values.
      i Found `NA` in `bounds`.
      v Supply finite numeric values for `L` and `U`.

# calibrate_linear() throws surveywts_error_calibration_not_converged for infeasible tight bounds

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(0.999,
        1.001), control = list(maxit = 25L))
    Condition
      Error in `.calibrate_nr_engine()`:
      x Calibration did not converge after 25 iterations.
      i The maximum relative misfit at termination was 28.384392.
      v Try increasing `maxit`, relaxing `epsilon`, or widening the `bounds`.

# E_abs: bounds = c(-1, 2) with bounds_scale='absolute' throws surveywts_error_bounds_invalid_calibration

    Code
      calibrate_linear(df, targets = targets, weights = base_weight, bounds = c(-1, 2),
      bounds_scale = "absolute")
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "absolute"`, the lower bound `L` must be strictly positive.
      i Got `L = -1`.
      v Supply `bounds = c(L, U)` where `0 < L < U`.

# HLE-1: calibrate_linear() rejects unit_scale with non-numeric type

    Code
      calibrate_linear(df_500, targets = targets, weights = base_weight, unit_scale = as.character(
        q_unequal))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 500.

# HLE-2: calibrate_linear() rejects unit_scale with wrong length

    Code
      calibrate_linear(df_500, targets = targets, weights = base_weight, unit_scale = q_unequal[
        -1L])
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must have length equal to the number of rows in `data`.
      i Got length 499 but expected 500.
      v Supply a positive numeric vector of length 500.

# HLE-3: calibrate_linear() rejects unit_scale with NA values

    Code
      calibrate_linear(df_500, targets = targets, weights = base_weight, unit_scale = q_na)
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must not contain `NA` values.
      i Found 1 `NA` value in `unit_scale`.
      v Remove `NA`s or set `unit_scale = NULL` to use uniform q-weights.

# HLE-4: calibrate_linear() rejects unit_scale with non-positive values

    Code
      calibrate_linear(df_500, targets = targets, weights = base_weight, unit_scale = q_nonpos)
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

# HLE-5: calibrate_linear() throws surveywts_error_calibration_not_converged with dual pattern

    Code
      calibrate_linear(df_tight, targets = targets_tight, weights = base_weight,
        bounds = c(0.999, 1.001), control = list(maxit = 1L, epsilon = 1e-15))
    Condition
      Error in `.calibrate_nr_engine()`:
      x Calibration did not converge after 1 iteration.
      i The maximum relative misfit at termination was 0.054782.
      v Try increasing `maxit`, relaxing `epsilon`, or widening the `bounds`.

