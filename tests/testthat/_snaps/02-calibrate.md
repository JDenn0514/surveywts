# calibrate_greg() rejects unsupported class

    Code
      calibrate_greg(list(x = 1), targets = targets)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <list>.
      v See package documentation for supported input types.

# calibrate_greg() rejects survey_replicate input

    Code
      calibrate_greg(rep_obj, targets = targets)
    Condition
      Error in `.check_input_class()`:
      x <survey_replicate> objects are not yet supported.
      i Replicate-weight support requires the Replicate release.
      v Use a <survey_taylor> design, or wait for the Replicate release.

# calibrate_greg() rejects 0-row data

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `calibrate_greg()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# calibrate_greg() rejects nonexistent weight column

    Code
      calibrate_greg(df, targets = targets, weights = nonexistent_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column nonexistent_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, and base_weight.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# calibrate_greg() rejects character weight column

    Code
      calibrate_greg(df, targets = targets, weights = chr_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column chr_wt must be numeric.
      i Got <character>.
      v Use `as.numeric(chr_wt)` to convert.

# calibrate_greg() rejects weight column with 0

    Code
      calibrate_greg(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# calibrate_greg() rejects weight column with NA

    Code
      calibrate_greg(df, targets = targets, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# calibrate_greg() rejects wt_name = c('a', 'b')

    Code
      calibrate_greg(df, targets = targets, wt_name = c("a", "b"))
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <character> of length 2.

# calibrate_greg() rejects wt_name = ''

    Code
      calibrate_greg(df, targets = targets, wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# calibrate_greg() rejects non-taylor reference_design

    Code
      calibrate_greg(df, targets = targets, reference_design = list())
    Condition
      Error in `.validate_reference_design()`:
      x `reference_design` must be a <survey_taylor> object or `NULL`.
      i Got <list>.
      v Pass a <survey_taylor> design as `reference_design`, or set `reference_design = NULL` to omit.

# calibrate_greg() rejects targets = 42 (not a list or data frame)

    Code
      calibrate_greg(df, targets = 42)
    Condition
      Error in `.parse_margins()`:
      x `targets` must be a named list or a data frame with columns variable, level, and target.
      i Got <numeric>.
      v See `calibrate_rake()` or `calibrate_greg()` documentation for accepted formats.

# calibrate_greg() rejects targets naming absent column

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `calibrate_greg()`:
      x Target variable nonexistent_var not found in `data`.
      i Names in `targets` must match column names in `data`.
      v Check spelling: available columns are id, age_group, sex, education, region, base_weight, and wts.

# calibrate_greg() rejects numeric calibration variable

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable num_var is <numeric>.
      i Currently only categorical (character or factor) variables are supported.
      v Convert to factor or character. Continuous auxiliary variable calibration is not currently supported.

# calibrate_greg() rejects calibration variable with NA

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `.validate_calibration_variables()`:
      x Calibration variable age_group contains 1 NA value(s).
      i NA values in calibration variables are not allowed.
      v Remove or impute NA values in age_group before calling `calibrate_greg()`.

# calibrate_greg() rejects targets missing a data level

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "55+" of variable age_group is present in `data` but not in `targets`.
      i Every level in the data must have a corresponding population target.
      v Add "55+" to the age_group entry in `targets`.

# calibrate_greg() rejects targets with extra level not in data

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `.validate_population_marginals()`:
      x Level "65+" of variable age_group is present in `targets` but not in `data`.
      i Population targets for levels absent from the sample are undefined.
      v Remove "65+" from the age_group entry in `targets`.

# calibrate_greg() rejects proportions summing to 0.9

    Code
      calibrate_greg(df, targets = targets)
    Condition
      Error in `.validate_population_marginals()`:
      x Population totals for age_group sum to 0.8, not 1.0.
      i When `type = "prop"`, each variable's targets must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in `targets$age_group`.

# calibrate_greg() rejects type='count' with inconsistent marginal sums

    Code
      calibrate_greg(df, targets = targets, type = "count")
    Condition
      Error in `.validate_count_marginal_consistency()`:
      x When `type = "count"`, all marginal vectors must sum to the same population total N (within 1e-3 tolerance).
      i Variable age_group sums to 500; variable sex sums to 550 (difference: 50).
      v Ensure all entries in `targets` refer to the same population total.

# calibrate_greg() warns on negative calibrated weights

    Code
      calibrate_greg(df, targets = targets, model = "linear")
    Condition
      Warning:
      ! Linear calibration produced 32 negative calibrated weight(s).
      i Negative weights can cause invalid variance estimates.
      i Consider `model = "logit"` for bounded weights, or review population totals.
    Output
      # A tibble: 100 x 7
            id age_group sex   education region    base_weight      wts
       * <int> <chr>     <chr> <chr>     <chr>           <dbl>    <dbl>
       1     1 35-54     F     HS        South           0.924 -0.00438
       2     2 55+       M     College   Northeast       1.17   0.00331
       3     3 35-54     M     College   Midwest         1.56   0.00319
       4     4 55+       M     Graduate  West            0.902  0.00331
       5     5 35-54     F     Graduate  South           1.65  -0.00438
       6     6 35-54     F     Graduate  West            0.559 -0.00438
       7     7 18-34     F     College   South           1.22   0.0426 
       8     8 35-54     M     HS        South           1.14   0.00319
       9     9 18-34     M     College   West            0.641  0.0502 
      10    10 35-54     M     Graduate  South           1.03   0.00319
      # i 90 more rows

# calibrate_greg() warns on unrecognized control key

    Code
      calibrate_greg(df, targets = targets, control = list(maxit = 10, pval = 0.05))
    Condition
      Warning:
      ! `control$pval` is not a recognized `calibrate_greg()` control parameter and will be ignored.
      i Valid `control` keys are: `maxit`, `epsilon`.
    Output
      # A tibble: 500 x 7
            id age_group sex   education region    base_weight     wts
       * <int> <chr>     <chr> <chr>     <chr>           <dbl>   <dbl>
       1     1 55+       F     College   South           0.730 0.00196
       2     2 18-34     M     College   Midwest         0.852 0.00189
       3     3 55+       F     Graduate  West            0.904 0.00196
       4     4 55+       M     <HS       Midwest         0.803 0.00182
       5     5 18-34     M     Graduate  Midwest         0.861 0.00189
       6     6 55+       M     College   Northeast       1.01  0.00182
       7     7 18-34     M     <HS       West            0.648 0.00189
       8     8 35-54     F     <HS       Midwest         1.22  0.00219
       9     9 18-34     F     HS        Northeast       0.739 0.00203
      10    10 35-54     F     Graduate  Northeast       0.775 0.00219
      # i 490 more rows

