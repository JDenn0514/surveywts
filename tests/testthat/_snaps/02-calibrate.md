# calibrate() rejects unsupported input class (SE-1)

    Code
      calibrate(matrix(1:6, 2, 3), variables = c(age_group), population = pop)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <matrix>.
      v See package documentation for supported input types.

# calibrate() rejects 0-row data frame (SE-2)

    Code
      calibrate(df, variables = c(age_group, sex), population = pop)
    Condition
      Error in `calibrate()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# calibrate() rejects survey_replicate input (SE-3)

    Code
      calibrate(rep_obj, variables = c(age_group, sex), population = pop)
    Condition
      Error in `.check_input_class()`:
      x <survey_replicate> objects are not supported in Phase 0.
      i Replicate-weight support requires Phase 1.
      v Use a <survey_taylor> design, or wait for Phase 1.

# calibrate() rejects named weight column not in data (SE-4)

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, weights = nonexistent_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column nonexistent_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, and base_weight.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# calibrate() rejects non-numeric weight column (SE-5)

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, weights = chr_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column chr_weight must be numeric.
      i Got <character>.
      v Use `as.numeric(chr_weight)` to convert.

# calibrate() rejects weight column with non-positive values (SE-6)

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# calibrate() rejects weight column with NA values (SE-7)

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# calibrate() validation order: empty_data fires before weights_not_found (SE-8)

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, weights = nonexistent_col)
    Condition
      Error in `calibrate()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# calibrate() rejects numeric calibration variable

    Code
      calibrate(df, variables = c(num_var), population = pop)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable num_var is <numeric>.
      i Phase 0 supports categorical (character or factor) variables only.
      v Convert to factor or character. Continuous auxiliary variable calibration is not supported in Phase 0.

# calibrate() rejects calibration variable with NA values

    Code
      calibrate(df, variables = c(age_group, sex), population = pop)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable age_group contains 1 NA value(s).
      i NA values in calibration variables are not allowed.
      v Remove or impute NA values in age_group before calling `calibrate()`.

# calibrate() rejects population name not found in data

    Code
      calibrate(df, variables = c(age_group), population = pop)
    Condition
      Error in `calibrate()`:
      x Population variable nonexistent_var not found in `data`.
      i Names in `population` must match column names in `data`.
      v Check spelling: available columns are id, age_group, sex, education, region, base_weight, and .weight.

# calibrate() rejects population missing a data level

    Code
      calibrate(df, variables = c(age_group, sex), population = pop)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "55+" of variable age_group is present in `data` but not in `population`.
      i Every level in the data must have a corresponding population target.
      v Add "55+" to the age_group entry in `population`.

# calibrate() rejects population with extra level absent from data

    Code
      calibrate(df, variables = c(age_group, sex), population = pop)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "65+" of variable age_group is present in `population` but not in `data`.
      i Population targets for levels absent from the sample are undefined.
      v Remove "65+" from the age_group entry in `population`.

# calibrate() rejects proportions that do not sum to 1

    Code
      calibrate(df, variables = c(age_group, sex), population = pop)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 0.8, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `population$age_group`.

# calibrate() rejects count targets that are non-positive

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, type = "count")
    Condition
      Error in `.validate_population_marginals()`:
      x Population targets for age_group contain 1 non-positive value(s).
      i When `type = "count"`, all targets must be strictly positive (> 0).
      v Remove or correct non-positive entries in `population$age_group`.

# calibrate() throws calibration_not_converged when maxit is reached

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, method = "logit",
      control = list(maxit = 1, epsilon = 1e-20))
    Condition
      Error in `.throw_not_converged()`:
      x Calibration did not converge after 1 iterations.
      i Maximum calibration error: 0.000562891 (tolerance: 1e-20).
      v Increase `control$maxit`, relax `control$epsilon`, or verify population totals are consistent with the sample.

# calibrate() with control$maxit = 0 throws not_converged with distinct note

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, control = list(
        maxit = 0))
    Condition
      Error in `.throw_not_converged_zero_maxit()`:
      x Calibration did not converge after 0 iterations.
      i Setting `control$maxit = 0` means no calibration is attempted.
      v Set `control$maxit` to a positive integer (default: 50).

# calibrate() warns when linear calibration produces negative weights

    Code
      calibrate(df, variables = c(age_group, sex), population = pop, method = "linear")
    Condition
      Warning:
      ! Linear calibration produced 36 negative calibrated weight(s).
      i Negative weights can cause invalid variance estimates.
      i Consider `method = "logit"` for bounded weights, or review population totals.
    Output
      # A tibble: 100 x 7
            id age_group sex   education region    base_weight  .weight
       * <int> <chr>     <chr> <chr>     <chr>           <dbl>    <dbl>
       1     1 35-54     M     Graduate  Midwest         0.634 -0.00434
       2     2 35-54     F     <HS       South           0.692  0.00365
       3     3 55+       F     Graduate  South           2.02   0.00454
       4     4 18-34     M     Graduate  Midwest         1.12   0.0356 
       5     5 35-54     M     HS        Northeast       1.74  -0.00434
       6     6 18-34     M     College   South           0.573  0.0356 
       7     7 35-54     F     College   Midwest         0.917  0.00365
       8     8 18-34     M     College   South           1.87   0.0356 
       9     9 55+       F     College   South           0.920  0.00454
      10    10 18-34     M     Graduate  West            1.75   0.0356 
      # i 90 more rows

