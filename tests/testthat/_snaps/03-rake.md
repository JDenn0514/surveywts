# rake() rejects unsupported input class (SE-1)

    Code
      rake(matrix(1:6, 2, 3), margins = margins)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame, <weighted_df>, <survey_taylor>, or <survey_calibrated>.
      i Got <matrix>.

# rake() rejects 0-row data frame (SE-2)

    Code
      rake(empty_df, margins = margins)
    Condition
      Error in `rake()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# rake() rejects survey_replicate input (SE-3)

    Code
      rake(rep_design, margins = margins)
    Condition
      Error in `.check_input_class()`:
      x <survey_replicate> objects are not supported in Phase 0.
      i Replicate-weight support requires Phase 1.
      v Use a <survey_taylor> design, or wait for Phase 1.

# rake() rejects named weight column missing from data (SE-4)

    Code
      rake(df, margins = margins, weights = nonexistent_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column nonexistent_wt not found in `data`.
      i Available columns: id, age_group, sex, education, region, and base_weight.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# rake() rejects non-numeric weight column (SE-5)

    Code
      rake(df, margins = margins, weights = bad_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column bad_wt must be numeric.
      i Got <character>.
      v Use `as.numeric(bad_wt)` to convert.

# rake() rejects non-positive weight column (SE-6)

    Code
      rake(df, margins = margins, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# rake() rejects NA in weight column (SE-7)

    Code
      rake(df, margins = margins, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# rake() empty_data fires before weights_not_found (SE-8)

    Code
      rake(empty_df, margins = margins, weights = missing_wt)
    Condition
      Error in `rake()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# rake() rejects margins that are not a list or data.frame

    Code
      rake(df, margins = c(0.5, 0.5))
    Condition
      Error in `.parse_margins()`:
      x `margins` must be a named list or a data frame with columns variable, level, and target.
      i Got <numeric>.
      v See `rake()` documentation for accepted formats.

# rake() rejects data.frame margins missing required columns

    Code
      rake(df, margins = bad_df)
    Condition
      Error in `.parse_margins()`:
      x `margins` must be a named list or a data frame with columns variable, level, and target.
      i Got <data.frame> but missing column(s): target.
      v See `rake()` documentation for accepted formats.

# rake() rejects margins with variable not in data

    Code
      rake(df, margins = margins)
    Condition
      Error in `rake()`:
      x Raking variable not_a_column not found in `data`.
      i Check that all variable names in `margins` exist as columns in `data`.

# rake() rejects numeric margin variable

    Code
      rake(df, margins = margins)
    Condition
      Error in `.validate_calibration_variables()`:
      x Raking variable income is <numeric>.
      i Phase 0 supports categorical (character or factor) variables only.
      v Convert to factor or character. Continuous auxiliary variable calibration is not supported in Phase 0.

# rake() rejects NA in a margin variable

    Code
      rake(df, margins = margins)
    Condition
      Error in `.validate_calibration_variables()`:
      x Raking variable age_group contains 1 NA value(s).
      i NA values in calibration variables are not allowed.
      v Remove or impute NA values in age_group before calling `rake()`.

# rake() rejects margins missing a data level (Format B input)

    Code
      rake(df, margins = margins_df)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "55+" of margin age_group is present in `data` but not in `margins`.
      i Every level in the data must have a corresponding population target.
      v Add "55+" to the age_group entry in `margins`.

# rake() rejects margins with level not in data

    Code
      rake(df, margins = margins)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "65+" of margin age_group is present in `margins` but not in `data`.
      i Population targets for levels absent from the sample are undefined.
      v Remove "65+" from the age_group entry in `margins`.

# rake() rejects margin proportions not summing to 1

    Code
      rake(df, margins = margins)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 0.7, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `margins$age_group`.

# rake() rejects non-positive count targets

    Code
      rake(df, margins = margins, type = "count")
    Condition
      Error in `.validate_population_marginals()`:
      x Population targets for age_group contain 1 non-positive value(s).
      i When `type = "count"`, all targets must be strictly positive (> 0).
      v Remove or correct non-positive entries in `margins$age_group`.

# rake() rejects proportions summing to 1.0 + 2e-6 (outside tolerance)

    Code
      rake(df, margins = margins)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 1.000002, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `margins$age_group`.

# rake() throws calibration_not_converged when survey method hits maxit

    Code
      rake(df, margins = margins, method = "survey", control = list(maxit = 1,
        epsilon = 1e-20))
    Condition
      Error in `.throw_not_converged()`:
      x Raking did not converge after 1 full sweeps.
      i Maximum margin error: 0.0458778 (tolerance: 1e-20).
      v Increase `control$maxit`, relax `control$epsilon`, or verify margin totals are consistent with the sample.

# rake() throws calibration_not_converged for maxit = 0

    Code
      rake(df, margins = margins, control = list(maxit = 0))
    Condition
      Error in `.throw_not_converged_zero_maxit()`:
      x Raking did not converge after 0 iterations.
      i Setting `control$maxit = 0` means no raking is attempted.
      v Set `control$maxit` to a positive integer.

# rake() warns when anesrake-specific control param set with method='survey'

    Code
      rake(df, margins = margins, method = "survey", control = list(pval = 0.01))
    Condition
      Warning:
      ! `control$pval` is not used when `method = "survey"` and will be ignored.
      i For `method = "anesrake"`, valid `control` keys are: `maxit`, `improvement`, `pval`, `min_cell_n`, `variable_select`.
      i For `method = "survey"`, valid `control` keys are: `maxit`, `epsilon`.
    Output
      # A tibble: 500 x 7
            id age_group sex   education region    base_weight .weight
       * <int> <chr>     <chr> <chr>     <chr>           <dbl>   <dbl>
       1     1 35-54     F     HS        South           2.55  0.00204
       2     2 18-34     F     Graduate  South           0.395 0.00171
       3     3 55+       F     HS        Northeast       1.20  0.00200
       4     4 35-54     M     HS        West            0.680 0.00224
       5     5 18-34     F     Graduate  South           0.793 0.00171
       6     6 18-34     M     HS        Midwest         0.554 0.00187
       7     7 18-34     F     HS        South           0.717 0.00171
       8     8 55+       M     Graduate  South           1.11  0.00219
       9     9 18-34     M     HS        South           0.647 0.00187
      10    10 55+       M     College   South           1.22  0.00219
      # i 490 more rows

# rake() warns when survey-specific control param set with method='anesrake'

    Code
      rake(df, margins = margins, method = "anesrake", control = list(epsilon = 1e-05))
    Condition
      Warning:
      ! `control$epsilon` is not used when `method = "anesrake"` and will be ignored.
      i For `method = "anesrake"`, valid `control` keys are: `maxit`, `improvement`, `pval`, `min_cell_n`, `variable_select`.
      i For `method = "survey"`, valid `control` keys are: `maxit`, `epsilon`.
    Message
      i Raking converged in 1 sweep: all variables already met their margins. Weights were not adjusted.
    Output
      # A tibble: 500 x 7
            id age_group sex   education region    base_weight .weight
       * <int> <chr>     <chr> <chr>     <chr>           <dbl>   <dbl>
       1     1 18-34     F     Graduate  South           2.53    0.002
       2     2 18-34     F     College   Northeast       1.23    0.002
       3     3 35-54     F     Graduate  South           1.47    0.002
       4     4 18-34     M     HS        Northeast       1.16    0.002
       5     5 55+       F     HS        Midwest         0.671   0.002
       6     6 55+       M     College   West            0.787   0.002
       7     7 18-34     M     HS        Midwest         1.07    0.002
       8     8 35-54     F     Graduate  South           0.310   0.002
       9     9 55+       M     College   South           0.712   0.002
      10    10 18-34     F     Graduate  Midwest         1.38    0.002
      # i 490 more rows

