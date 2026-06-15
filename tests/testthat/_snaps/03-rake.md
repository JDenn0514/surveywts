# calibrate_rake() rejects unsupported class

    Code
      calibrate_rake(list(x = 1), targets = targets)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <list>.
      v See package documentation for supported input types.

# calibrate_rake() rejects 0-row data

    Code
      calibrate_rake(empty_df, targets = targets)
    Condition
      Error in `calibrate_rake()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# calibrate_rake() rejects nonexistent weight column

    Code
      calibrate_rake(df, targets = targets, weights = nonexistent_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column nonexistent_wt not found in `data`.
      i Available columns: id, age_group, sex, education, region, and base_weight.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# calibrate_rake() rejects character weight column

    Code
      calibrate_rake(df, targets = targets, weights = bad_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column bad_wt must be numeric.
      i Got <character>.
      v Use `as.numeric(bad_wt)` to convert.

# calibrate_rake() rejects weight column with 0

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# calibrate_rake() rejects weight column with NA

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# calibrate_rake() rejects wt_name = c('a', 'b')

    Code
      calibrate_rake(df, targets = targets, wt_name = c("a", "b"))
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <character> of length 2.

# calibrate_rake() rejects wt_name = ''

    Code
      calibrate_rake(df, targets = targets, wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# calibrate_rake() rejects non-taylor reference_design

    Code
      calibrate_rake(df, targets = targets, reference_design = "bad")
    Condition
      Error in `.validate_reference_design()`:
      x `reference_design` must be a <survey_taylor>.
      i Got class <character>.
      v Pass the <survey_taylor> object used to compute the targets.

# calibrate_rake() rejects targets = 42

    Code
      calibrate_rake(df, targets = 42)
    Condition
      Error in `.parse_margins()`:
      x `targets` must be a named list or a data frame with columns variable, level, and target.
      i Got <numeric>.
      v See `calibrate_rake()` or `calibrate_greg()` documentation for accepted formats.

# calibrate_rake() rejects Format B data frame missing 'level' column

    Code
      calibrate_rake(df, targets = bad_df)
    Condition
      Error in `.parse_margins()`:
      x `targets` must be a named list or a data frame with columns variable, level, and target.
      i Got <data.frame> but missing column(s): level.
      v See `calibrate_rake()` or `calibrate_greg()` documentation for accepted formats.

# calibrate_rake() rejects targets naming absent column

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `calibrate_rake()`:
      x Raking variable not_a_column not found in `data`.
      i Check that all variable names in `targets` exist as columns in `data`.

# calibrate_rake() rejects numeric raking variable

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_calibration_variables()`:
      x Raking variable income is <numeric>.
      i Currently only categorical (character or factor) variables are supported.
      v Convert to factor or character. Continuous auxiliary variable calibration is not currently supported.

# calibrate_rake() rejects raking variable with NA

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_calibration_variables()`:
      x Raking variable age_group contains 1 NA value(s).
      i NA values in calibration variables are not allowed.
      v Remove or impute NA values in age_group before calling `calibrate_rake()`.

# calibrate_rake() rejects targets missing a data level

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "55+" of variable age_group is present in `data` but not in `targets`.
      i Every level in the data must have a corresponding population target.
      v Add "55+" to the age_group entry in `targets`.

# calibrate_rake() rejects targets with level not in data

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "65+" of variable age_group is present in `targets` but not in `data`.
      i Population targets for levels absent from the sample are undefined.
      v Remove "65+" from the age_group entry in `targets`.

# calibrate_rake() rejects proportions summing to 1.1

    Code
      calibrate_rake(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 1.1, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `targets$age_group`.

# calibrate_rake() rejects type='count' with inconsistent marginal sums

    Code
      calibrate_rake(df, targets = targets, weights = base_weight, type = "count")
    Condition
      Error in `.validate_count_marginal_consistency()`:
      x When `type = "count"`, all marginal vectors must sum to the same population total N (within 1e-3 tolerance).
      i Variable age_group sums to 500; variable sex sums to 550 (difference: 50).
      v Ensure all entries in `targets` refer to the same population total.

# calibrate_rake() throws calibration_not_converged hitting maxit (nr)

    Code
      calibrate_rake(df, targets = targets, weights = base_weight, algorithm = "nr",
        control = list(maxit = 1L, epsilon = 1e-20))
    Condition
      Error in `.calibrate_nr_engine()`:
      x Calibration did not converge after 1 iteration.
      i The maximum relative misfit at termination was 0.004117.
      v Try increasing `maxit`, relaxing `epsilon`, or widening the `bounds`.

# calibrate_rake() rejects cap with algorithm = 'nr'

    Code
      calibrate_rake(df, targets = targets, weights = base_weight, algorithm = "nr",
        cap = 3)
    Condition
      Error in `calibrate_rake()`:
      x `cap` is not supported when `algorithm = "nr"`.
      i The Newton-Raphson raking engine does not support per-step weight capping.
      v Use `algorithm = "classic_ipf"` for raking with a weight cap.

# calibrate_rake() rejects cap = 0

    Code
      calibrate_rake(df, targets = targets, weights = base_weight, cap = 0,
        algorithm = "classic_ipf")
    Condition
      Error in `calibrate_rake()`:
      x `cap` must be a positive finite numeric scalar.
      i Got 0.
      v Use a value > 0 (e.g., `cap = 5`) or `cap = NULL` to disable capping.

# calibrate_rake() warns for classic_ipf-specific control param with algorithm='nr'

    Code
      calibrate_rake(df, targets = targets, weights = base_weight, algorithm = "nr",
        control = list(pval = 0.01))
    Condition
      Warning:
      ! `control$pval` is not used when `algorithm = "nr"` and will be ignored.
      i For `algorithm = "classic_ipf"`, valid `control` keys are: `maxit`, `improvement`, `pval`, `min_cell_n`, `variable_select`.
      i For `algorithm = "nr"`, valid `control` keys are: `maxit`, `epsilon`.
    Output
      # A tibble: 500 x 7
            id age_group sex   education region    base_weight   wts
       * <int> <chr>     <chr> <chr>     <chr>           <dbl> <dbl>
       1     1 35-54     F     Graduate  South           0.677 0.601
       2     2 55+       F     HS        South           1.24  1.35 
       3     3 35-54     M     Graduate  Northeast       1.09  0.947
       4     4 55+       F     College   Northeast       0.950 1.03 
       5     5 35-54     F     College   Northeast       1.06  0.944
       6     6 35-54     M     College   South           1.01  0.873
       7     7 18-34     M     Graduate  Northeast       0.757 0.846
       8     8 35-54     F     College   Midwest         0.832 0.738
       9     9 18-34     M     College   West            1.05  1.17 
      10    10 35-54     F     Graduate  West            1.06  0.939
      # i 490 more rows

# calibrate_rake() warns for nr-specific control param with algorithm='classic_ipf'

    Code
      calibrate_rake(df, targets = targets, weights = base_weight, algorithm = "classic_ipf",
        control = list(epsilon = 1e-09))
    Condition
      Warning:
      ! `control$epsilon` is not used when `algorithm = "classic_ipf"` and will be ignored.
      i For `algorithm = "classic_ipf"`, valid `control` keys are: `maxit`, `improvement`, `pval`, `min_cell_n`, `variable_select`.
      i For `algorithm = "nr"`, valid `control` keys are: `maxit`, `epsilon`.
    Output
      # A tibble: 500 x 7
            id age_group sex   education region    base_weight   wts
       * <int> <chr>     <chr> <chr>     <chr>           <dbl> <dbl>
       1     1 55+       F     College   South           0.730 0.650
       2     2 18-34     M     College   Midwest         0.852 0.781
       3     3 55+       F     Graduate  West            0.904 0.805
       4     4 55+       M     <HS       Midwest         0.803 0.694
       5     5 18-34     M     Graduate  Midwest         0.861 0.790
       6     6 55+       M     College   Northeast       1.01  0.876
       7     7 18-34     M     <HS       West            0.648 0.594
       8     8 35-54     F     <HS       Midwest         1.22  1.18 
       9     9 18-34     F     HS        Northeast       0.739 0.699
      10    10 35-54     F     Graduate  Northeast       0.775 0.751
      # i 490 more rows

