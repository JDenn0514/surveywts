# adjust_nonresponse() rejects unsupported class (SE-1)

    Code
      adjust_nonresponse(m, response_status = x)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame, <weighted_df>, <survey_taylor>, or <survey_nonprob>.
      i Got <matrix>.

# adjust_nonresponse() rejects empty data frame (SE-2)

    Code
      adjust_nonresponse(df_empty, response_status = responded)
    Condition
      Error in `adjust_nonresponse()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# adjust_nonresponse() rejects survey_replicate input (SE-3)

    Code
      adjust_nonresponse(rep_design, response_status = responded)
    Condition
      Error in `.check_input_class()`:
      x <survey_replicate> objects are not supported in Phase 0.
      i Replicate-weight support requires Phase 1.
      v Use a <survey_taylor> design, or wait for Phase 1.

# adjust_nonresponse() rejects missing weight column (SE-4)

    Code
      adjust_nonresponse(df, response_status = responded, weights = no_such_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column no_such_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, base_weight, and responded.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# adjust_nonresponse() rejects non-numeric weight column (SE-5)

    Code
      adjust_nonresponse(df, response_status = responded, weights = char_wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column char_wt must be numeric.
      i Got <character>.
      v Use `as.numeric(char_wt)` to convert.

# adjust_nonresponse() rejects non-positive weights (SE-6)

    Code
      adjust_nonresponse(df, response_status = responded, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# adjust_nonresponse() rejects NA in weight column (SE-7)

    Code
      adjust_nonresponse(df, response_status = responded, weights = base_weight)
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# adjust_nonresponse() empty_data fires before weights_not_found (SE-8)

    Code
      adjust_nonresponse(df_empty, response_status = responded, weights = no_such_col)
    Condition
      Error in `adjust_nonresponse()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# adjust_nonresponse() rejects by variable with NA values

    Code
      adjust_nonresponse(df, response_status = responded, by = age_group)
    Condition
      Error in `adjust_nonresponse()`:
      x Weighting class variable age_group contains 1 NA value(s).
      i NA values in weighting class variables are not allowed.
      v Remove or impute NA values in age_group before calling `adjust_nonresponse()`.

# adjust_nonresponse() rejects response_status with NA values

    Code
      adjust_nonresponse(df, response_status = responded)
    Condition
      Error in `adjust_nonresponse()`:
      x Response status column responded contains 1 NA value(s).
      i The response indicator must be fully observed.
      v Remove rows with missing response status before calling `adjust_nonresponse()`.

# adjust_nonresponse() rejects missing response_status column

    Code
      adjust_nonresponse(df, response_status = responded)
    Condition
      Error in `adjust_nonresponse()`:
      x Response status column responded not found in `data`.
      i Available columns: id, age_group, sex, education, region, base_weight, and .weight.
      v Pass the column name as a bare name, e.g., `response_status = responded`.

# adjust_nonresponse() rejects response_status with non-binary integer values

    Code
      adjust_nonresponse(df, response_status = resp_bad)
    Condition
      Error in `.validate_response_status_binary()`:
      x Response status column resp_bad must be binary (0/1 or logical).
      i Got <integer> with values: 0, 1, and 2.
      i Factor columns are not binary regardless of their levels.
      v Convert to logical (`TRUE`/`FALSE`) or integer (`0`/`1`) before calling `adjust_nonresponse()`.

# adjust_nonresponse() rejects factor response_status (not binary)

    Code
      adjust_nonresponse(df, response_status = resp_factor)
    Condition
      Error in `.validate_response_status_binary()`:
      x Response status column resp_factor must be binary (0/1 or logical).
      i Got <factor> with values: R and NR.
      i Factor columns are not binary regardless of their levels.
      v Convert to logical (`TRUE`/`FALSE`) or integer (`0`/`1`) before calling `adjust_nonresponse()`.

# adjust_nonresponse() rejects data with all nonrespondents

    Code
      adjust_nonresponse(df, response_status = responded)
    Condition
      Error in `adjust_nonresponse()`:
      x No respondents found in `data`.
      i All values of responded are 0 or `FALSE`.
      v Ensure `data` contains both respondents and nonrespondents before adjustment.

# adjust_nonresponse() rejects by-cell with no respondents

    Code
      adjust_nonresponse(df, response_status = responded, weights = w, by = class)
    Condition
      Error in `adjust_nonresponse()`:
      x Weighting class cell "B" has no respondents.
      i Cannot redistribute nonrespondent weights to an empty respondent cell.
      v Collapse weighting classes to ensure each cell has at least one respondent.

# adjust_nonresponse() rejects method = 'propensity' (Phase 2 stub)

    Code
      adjust_nonresponse(df, response_status = responded, method = "propensity")
    Condition
      Error in `adjust_nonresponse()`:
      x `method = "propensity"` is not available in Phase 0.
      i Propensity-based methods ("\"propensity\"" and "\"propensity-cell\"") require Phase 2 (v0.3.0).
      v Use `method = "weighting-class"` for now.

# adjust_nonresponse() rejects method = 'propensity-cell' (Phase 2 stub)

    Code
      adjust_nonresponse(df, response_status = responded, method = "propensity-cell")
    Condition
      Error in `adjust_nonresponse()`:
      x `method = "propensity-cell"` is not available in Phase 0.
      i Propensity-based methods ("\"propensity\"" and "\"propensity-cell\"") require Phase 2 (v0.3.0).
      v Use `method = "weighting-class"` for now.

# adjust_nonresponse() warns when a cell has fewer than 20 respondents

    Code
      adjust_nonresponse(df_small, response_status = responded, weights = w, by = class)
    Condition
      Warning:
      ! Weighting class cell "small" is sparse (5 respondent(s), adjustment factor 1.40×).
      i Small or high-adjustment cells may produce extreme weights.
      i Consider collapsing weighting classes or adjusting `control$min_cell` / `control$max_adjust`.
    Output
      # A tibble: 85 x 3
         class responded     w
       * <chr>     <int> <dbl>
       1 small         1  1.4 
       2 small         1  1.4 
       3 small         1  1.4 
       4 small         1  1.4 
       5 small         1  1.4 
       6 big           1  1.25
       7 big           1  1.25
       8 big           1  1.25
       9 big           1  1.25
      10 big           1  1.25
      # i 75 more rows

# adjust_nonresponse() rejects character response_status (not binary)

    Code
      adjust_nonresponse(df, response_status = resp_char)
    Condition
      Error in `.validate_response_status_binary()`:
      x Response status column resp_char must be binary (0/1 or logical).
      i Got <character> with values: "yes" and "no".
      i Factor columns are not binary regardless of their levels.
      v Convert to logical (`TRUE`/`FALSE`) or integer (`0`/`1`) before calling `adjust_nonresponse()`.

