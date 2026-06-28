# H1: calibrate_linear() aborts with cli error for data.frame input

    Code
      calibrate_linear(df, targets = targets)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# H10: extreme targets producing negative weights error for S7 input

    Code
      calibrate_linear(design, targets = targets)
    Condition
      Error in `calibrate_linear()`:
      x Linear calibration produced 162 negative calibrated weights.
      i Negative calibrated weights cannot be stored in a survey object.
      v Use `calibrate_logit()` or `calibrate_rake()` for bounded positive weights, or review population targets.

# E1: calibrate_linear() throws surveywts_error_not_survey_base for bad input

    Code
      calibrate_linear(list(x = 1:3), targets = list())
    Condition
      Error in `.check_input_class()`:
      x `data` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <list>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# E2: calibrate_linear() throws surveywts_error_empty_data for 0-row input

    Code
      calibrate_linear(empty_taylor, targets = targets)
    Condition
      Error in `calibrate_linear()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# E3: calibrate_linear() throws surveywts_error_wt_name_not_scalar

    Code
      calibrate_linear(taylor, targets = targets, wt_name = c("a", "b"))
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <character> of length 2.

# E4: calibrate_linear() throws surveywts_error_wt_name_empty for NA wt_name

    Code
      calibrate_linear(taylor, targets = targets, wt_name = NA_character_)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# E5: calibrate_linear() throws surveywts_error_reference_design_not_taylor

    Code
      calibrate_linear(taylor, targets = targets, reference_design = "not_a_design")
    Condition
      Error in `.validate_reference_design()`:
      x `reference_design` must be a <survey_taylor>.
      i Got class <character>.
      v Pass the <survey_taylor> object used to compute the targets.

# E10: calibrate_linear() throws surveywts_error_targets_variable_not_found

    Code
      calibrate_linear(taylor, targets = targets)
    Condition
      Error in `calibrate_linear()`:
      x Target variable nonexistent_var not found in `data`.
      i Names in `targets` must match column names in `data`.
      v Check spelling: available columns are id, age_group, sex, education, region, and base_weight.

# E11: calibrate_linear() throws surveywts_error_variable_not_categorical

    Code
      calibrate_linear(taylor, targets = targets)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable id is <integer>.
      i Currently only categorical (character or factor) variables are supported.
      v Convert to factor or character. Continuous auxiliary variable calibration is not currently supported.

# E12: calibrate_linear() throws surveywts_error_variable_has_na

    Code
      calibrate_linear(taylor, targets = targets)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable age_group contains 1 NA value(s).
      i NA values in calibration variables are not allowed.
      v Remove or impute NA values in age_group before calling `calibrate_linear()`.

# E13: calibrate_linear() throws surveywts_error_population_level_missing

    Code
      calibrate_linear(taylor, targets = targets)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "55+" of variable age_group is present in `data` but not in `targets`.
      i Every level in the data must have a corresponding population target.
      v Add "55+" to the age_group entry in `targets`.

# E14: calibrate_linear() throws surveywts_error_population_level_extra

    Code
      calibrate_linear(taylor, targets = targets)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "65+" of variable age_group is present in `targets` but not in `data`.
      i Population targets for levels absent from the sample are undefined.
      v Remove "65+" from the age_group entry in `targets`.

# E15: calibrate_linear() throws surveywts_error_population_totals_invalid (prop != 1)

    Code
      calibrate_linear(taylor, targets = targets)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 1.2, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `targets$age_group`.

# E16: calibrate_linear() throws surveywts_error_population_totals_invalid (count <= 0)

    Code
      calibrate_linear(taylor, targets = targets, type = "count")
    Condition
      Error in `.validate_population_marginals()`:
      x Population targets for age_group contain 1 non-positive value(s).
      i When `type = "count"`, all targets must be strictly positive (> 0).
      v Remove or correct non-positive entries in `targets$age_group`.

# E17: calibrate_linear() throws surveywts_error_margins_format_invalid for bad targets

    Code
      calibrate_linear(taylor, targets = 42)
    Condition
      Error in `.parse_margins()`:
      x `targets` must be a named list or a data frame with columns variable, level, and target.
      i Got <numeric>.
      v See `calibrate_rake()`, `calibrate_linear()`, or `calibrate_logit()` documentation for accepted formats.

# E18: calibrate_linear() throws surveywts_error_bounds_invalid_calibration (L >= 1)

    Code
      calibrate_linear(taylor, targets = targets, bounds = c(1, 3))
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "multiplicative"`, the lower bound `L` must be strictly less than 1.
      i Got `L = 1`.
      v Supply `bounds = c(L, U)` where `L < 1 < U`, e.g. `c(0.5, 2)`.

# E19: calibrate_linear() throws surveywts_error_bounds_invalid_calibration (U <= 1)

    Code
      calibrate_linear(taylor, targets = targets, bounds = c(0.3, 0.9))
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "multiplicative"`, the upper bound `U` must be strictly greater than 1.
      i Got `U = 0.9`.
      v Supply `bounds = c(L, U)` where `L < 1 < U`, e.g. `c(0.5, 2)`.

# E20: calibrate_linear() throws surveywts_error_unit_scale_invalid (not numeric)

    Code
      calibrate_linear(taylor, targets = targets, unit_scale = rep("1", nrow(df)))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 50.

# calibrate_linear() throws surveywts_error_bounds_invalid_calibration for bounds length != 2

    Code
      calibrate_linear(taylor, targets = targets, bounds = c(0.5, 2, 3))
    Condition
      Error in `.validate_bounds()`:
      x `bounds` must be a numeric vector of length 2.
      i Got length 3.
      v Supply `bounds = c(L, U)` where `L < 1 < U`.

# calibrate_linear() throws surveywts_error_bounds_invalid_calibration for bounds with NA

    Code
      calibrate_linear(taylor, targets = targets, bounds = c(NA, 2))
    Condition
      Error in `.validate_bounds()`:
      x `bounds` must not contain `NA` values.
      i Found `NA` in `bounds`.
      v Supply finite numeric values for `L` and `U`.

# calibrate_linear() throws surveywts_error_calibration_not_converged for infeasible tight bounds

    Code
      calibrate_linear(taylor, targets = targets, bounds = c(0.999, 1.001), control = list(
        maxit = 25L))
    Condition
      Error in `.calibrate_nr_engine()`:
      x Calibration did not converge after 25 iterations.
      i The maximum relative misfit at termination was 28.384392.
      v Try increasing `maxit`, relaxing `epsilon`, or widening the `bounds`.

# W2: calibrate_linear() errors with surveywts_error_negative_calibrated_weights for S7 input

    Code
      calibrate_linear(design_w2, targets = targets)
    Condition
      Error in `calibrate_linear()`:
      x Linear calibration produced 162 negative calibrated weights.
      i Negative calibrated weights cannot be stored in a survey object.
      v Use `calibrate_logit()` or `calibrate_rake()` for bounded positive weights, or review population targets.

# E_abs: bounds = c(-1, 2) with bounds_scale='absolute' throws surveywts_error_bounds_invalid_calibration

    Code
      calibrate_linear(taylor, targets = targets, bounds = c(-1, 2), bounds_scale = "absolute")
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "absolute"`, the lower bound `L` must be strictly positive.
      i Got `L = -1`.
      v Supply `bounds = c(L, U)` where `0 < L < U`.

# HLE-1: calibrate_linear() rejects unit_scale with non-numeric type

    Code
      calibrate_linear(taylor_500, targets = targets, unit_scale = as.character(
        q_unequal))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 500.

# HLE-2: calibrate_linear() rejects unit_scale with wrong length

    Code
      calibrate_linear(taylor_500, targets = targets, unit_scale = q_unequal[-1L])
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must have length equal to the number of rows in `data`.
      i Got length 499 but expected 500.
      v Supply a positive numeric vector of length 500.

# HLE-3: calibrate_linear() rejects unit_scale with NA values

    Code
      calibrate_linear(taylor_500, targets = targets, unit_scale = q_na)
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must not contain `NA` values.
      i Found 1 `NA` value in `unit_scale`.
      v Remove `NA`s or set `unit_scale = NULL` to use uniform q-weights.

# HLE-4: calibrate_linear() rejects unit_scale with non-positive values

    Code
      calibrate_linear(taylor_500, targets = targets, unit_scale = q_nonpos)
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

# HLE-5: calibrate_linear() throws surveywts_error_calibration_not_converged with dual pattern

    Code
      calibrate_linear(taylor_tight, targets = targets_tight, bounds = c(0.999, 1.001),
      control = list(maxit = 1L, epsilon = 1e-15))
    Condition
      Error in `.calibrate_nr_engine()`:
      x Calibration did not converge after 1 iteration.
      i The maximum relative misfit at termination was 0.054782.
      v Try increasing `maxit`, relaxing `epsilon`, or widening the `bounds`.

