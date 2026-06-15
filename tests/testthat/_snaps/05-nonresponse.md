# adjust_nonresponse() rejects unsupported class (SE-1)

    Code
      adjust_nonresponse(m, response_status = x)
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame or a supported survey design object.
      i Got <matrix>.
      v See package documentation for supported input types.

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
      Error in `adjust_nonresponse()`:
      x <survey_replicate> objects are not supported by `adjust_nonresponse()`.
      i Replicate-weight support for nonresponse adjustment is not yet available.
      v Use a <survey_taylor> or <survey_nonprob> design.

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
      Error in `value[[3L]]()`:
      x `response_status` column not found in `data`.
      i Available columns: id, age_group, sex, education, region, base_weight, and wts.
      v Pass a single bare column name, e.g., `response_status = responded`.

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

# adjust_nonresponse() warns when a cell has fewer than 20 respondents

    Code
      adjust_nonresponse(df_small, response_status = responded, weights = w, by = class)
    Condition
      Warning:
      ! Weighting class cell "small" is sparse (5 respondent(s), adjustment factor 1.40×).
      i Small or high-adjustment cells may produce extreme weights.
      i Consider collapsing weighting classes or adjusting `control$min_cell` / `control$max_adjust`.
    Output
      # A tibble: 107 x 4
         class responded     w   wts
       * <chr>     <int> <dbl> <dbl>
       1 small         1     1  1.4 
       2 small         1     1  1.4 
       3 small         1     1  1.4 
       4 small         1     1  1.4 
       5 small         1     1  1.4 
       6 small         0     1  0   
       7 small         0     1  0   
       8 big           1     1  1.25
       9 big           1     1  1.25
      10 big           1     1  1.25
      # i 97 more rows

# adjust_nonresponse() rejects character response_status (not binary)

    Code
      adjust_nonresponse(df, response_status = resp_char)
    Condition
      Error in `.validate_response_status_binary()`:
      x Response status column resp_char must be binary (0/1 or logical).
      i Got <character> with values: "yes" and "no".
      i Factor columns are not binary regardless of their levels.
      v Convert to logical (`TRUE`/`FALSE`) or integer (`0`/`1`) before calling `adjust_nonresponse()`.

# adjust_nonresponse() rejects response_status selecting multiple columns

    Code
      adjust_nonresponse(df, response_status = c(responded, responded2))
    Condition
      Error in `adjust_nonresponse()`:
      x `response_status` must select exactly one column.
      i Got 2 column(s).
      v Pass a single bare column name, e.g., `response_status = responded`.

# adjust_nonresponse() rejects non-character wt_name

    Code
      adjust_nonresponse(df, response_status = responded, wt_name = 42)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <numeric> of length 1.

# adjust_nonresponse() rejects empty wt_name

    Code
      adjust_nonresponse(df, response_status = responded, wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# adjust_nonresponse() rejects NA wt_name

    Code
      adjust_nonresponse(df, response_status = responded, wt_name = NA_character_)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# redistribute_weights() errors for survey_replicate input

    Code
      redistribute_weights(rsd, reduce_if = x, increase_if = y)
    Condition
      Error in `redistribute_weights()`:
      x <survey_replicate> objects are not supported by `redistribute_weights()`.
      i Replicate-weight support for weight redistribution is not yet available.
      v Use a <survey_taylor> or <survey_nonprob> design.

# redistribute_weights() errors for 0-row data frame

    Code
      redistribute_weights(empty_df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt)
    Condition
      Error in `redistribute_weights()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# redistribute_weights() errors when named weight column is missing

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = no_such_col)
    Condition
      Error in `.validate_weights()`:
      x Weight column no_such_col not found in `data`.
      i Available columns: reduce_col and increase_col.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# redistribute_weights() errors when weight column is not numeric

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column wt must be numeric.
      i Got <character>.
      v Use `as.numeric(wt)` to convert.

# redistribute_weights() errors when weight column has non-positive values

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column wt contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# redistribute_weights() errors when weight column has NA

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt)
    Condition
      Error in `.validate_weights()`:
      x Weight column wt contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# redistribute_weights() errors when wt_name is not character(1)

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt, wt_name = 42)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <numeric> of length 1.

# redistribute_weights() errors when wt_name is NA or empty string

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt, wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# redistribute_weights() errors when wt_name conflicts with an existing non-weight column

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        wt_name = "age_group")
    Condition
      Error in `redistribute_weights()`:
      x `wt_name` "age_group" conflicts with an existing column in `data`.
      i age_group is already present and is not the weight column.
      v Choose a different name for the output weight column.

# redistribute_weights() errors when reduce_if column is not found

    Code
      redistribute_weights(df, reduce_if = no_such_col, increase_if = increase_col)
    Condition
      Error in `redistribute_weights()`:
      x `reduce_if` column no_such_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, base_weight, responded, increase_col, and wts.
      v Pass a bare column name, e.g., `reduce_if = my_indicator`.

# redistribute_weights() errors when increase_if column is not found

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = no_such_col)
    Condition
      Error in `redistribute_weights()`:
      x `increase_if` column no_such_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, base_weight, responded, reduce_col, and wts.
      v Pass a bare column name, e.g., `increase_if = my_indicator`.

# redistribute_weights() errors when reduce_if is not binary (factor input)

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
    Condition
      Error in `.validate_response_status_binary()`:
      x reduce_if column reduce_col must be binary (0/1 or logical).
      i Got <factor> with values: 0 and 1.
      i Factor columns are not binary regardless of their levels.
      v Convert to logical (`TRUE`/`FALSE`) or integer (`0`/`1`) before calling `redistribute_weights()`.

# redistribute_weights() errors when increase_if is not binary (character input)

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
    Condition
      Error in `.validate_response_status_binary()`:
      x increase_if column increase_col must be binary (0/1 or logical).
      i Got <character> with values: "1" and "0".
      i Factor columns are not binary regardless of their levels.
      v Convert to logical (`TRUE`/`FALSE`) or integer (`0`/`1`) before calling `redistribute_weights()`.

# redistribute_weights() errors when reduce_if has NA values

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
    Condition
      Error in `redistribute_weights()`:
      x `reduce_if` column reduce_col contains 1 NA value(s).
      i The reduce indicator must be fully observed.
      v Remove rows with missing values in reduce_col before calling `redistribute_weights()`.

# redistribute_weights() errors when increase_if has NA values

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col)
    Condition
      Error in `redistribute_weights()`:
      x `increase_if` column increase_col contains 1 NA value(s).
      i The increase indicator must be fully observed.
      v Remove rows with missing values in increase_col before calling `redistribute_weights()`.

# redistribute_weights() errors when reduce_if and increase_if overlap

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt)
    Condition
      Error in `redistribute_weights()`:
      x 1 row(s) have both `reduce_if` and `increase_if` set to `TRUE`.
      i `reduce_if` and `increase_if` must be mutually exclusive.
      v Ensure no row has both indicators set to 1 or `TRUE`.

# redistribute_weights() errors when a group has no increase_if rows

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt)
    Condition
      Error in `redistribute_weights()`:
      x Group "(all rows)" has 5 reduce_if row(s) but no increase_if rows.
      i Cannot redistribute weight to an empty recipient set.
      v Ensure each group has at least one row with `increase_if` = `TRUE`.

# redistribute_weights() errors when a by variable has NA values

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        by = age_group)
    Condition
      Error in `redistribute_weights()`:
      x By variable age_group contains 1 NA value(s).
      i NA values in grouping variables are not allowed.
      v Remove or impute NA values in age_group before calling `redistribute_weights()`.

# redistribute_weights() with by: one group all-reduce triggers error, other groups succeed

    Code
      redistribute_weights(df, reduce_if = reduce_col, increase_if = increase_col,
        weights = wt, by = grp)
    Condition
      Error in `redistribute_weights()`:
      x Group "B" has 2 reduce_if row(s) but no increase_if rows.
      i Cannot redistribute weight to an empty recipient set.
      v Ensure each group has at least one row with `increase_if` = `TRUE`.

# adjust_nonresponse() errors when method='propensity-cell' and formula is NULL

    Code
      adjust_nonresponse(df, response_status = responded, method = "propensity-cell")
    Condition
      Error in `adjust_nonresponse()`:
      x `formula` is required when `method = "propensity-cell"`.
      i Provide a one-sided formula, e.g., `formula = ~ age_group + sex`.

# adjust_nonresponse() errors when formula is not a formula object (propensity-cell)

    Code
      adjust_nonresponse(df, response_status = responded, formula = "age_group",
        method = "propensity-cell")
    Condition
      Error in `.validate_formula()`:
      x `formula` must be a one-sided formula (e.g., `~ age + sex`).
      i Got <character>.

# adjust_nonresponse() errors when a formula variable is missing (propensity-cell)

    Code
      adjust_nonresponse(df, response_status = responded, formula = ~nonexistent_var,
        method = "propensity-cell")
    Condition
      Error in `.validate_formula_variables()`:
      x Variable nonexistent_var not found in `data`.
      i All variables in `formula` must be columns in `data`.
      v Check spelling or add nonexistent_var to the data before calling this function.

# adjust_nonresponse() errors when a formula variable has NA values

    Code
      adjust_nonresponse(df, response_status = responded, formula = ~age_group,
        method = "propensity-cell")
    Condition
      Error in `adjust_nonresponse()`:
      x Formula variable age_group contains 1 NA value(s).
      i All formula variables must be fully observed for GLM fitting.
      v Remove or impute NA values in age_group before calling `adjust_nonresponse()`.

# adjust_nonresponse() errors when control$n_cells = 1

    Code
      adjust_nonresponse(df, response_status = responded, formula = ~age_group,
        method = "propensity-cell", control = list(n_cells = 1))
    Condition
      Error in `adjust_nonresponse()`:
      x `control$n_cells` must be a whole number >= 2.
      i Got 1.
      v Set `control$n_cells` to an integer >= 2, e.g., `control = list(n_cells = 5)`.

# adjust_nonresponse() errors when a propensity cell contains no respondents

    Code
      adjust_nonresponse(df_no_resp, response_status = responded, weights = wt,
        formula = ~x_pred, method = "propensity-cell", control = list(n_cells = 10))
    Condition
      Error in `adjust_nonresponse()`:
      x Propensity cell 1 has no respondents.
      i Propensity score range for cell 1: [0.0511, 0.0528].
      v Reduce `control$n_cells` or ensure respondents exist across all propensity score strata.

# adjust_nonresponse(propensity) errors when formula = NULL

    Code
      adjust_nonresponse(df, response_status = responded, method = "propensity")
    Condition
      Error in `adjust_nonresponse()`:
      x `formula` is required when `method = "propensity"`.
      i Provide a one-sided formula, e.g., `formula = ~ age_group + sex`.

# adjust_nonresponse(propensity) errors when formula is not a formula

    Code
      adjust_nonresponse(df, response_status = responded, formula = "age_group + sex",
        method = "propensity")
    Condition
      Error in `.validate_formula()`:
      x `formula` must be a one-sided formula (e.g., `~ age + sex`).
      i Got <character>.

# adjust_nonresponse(propensity) errors when formula variable is missing

    Code
      adjust_nonresponse(df, response_status = responded, formula = ~nonexistent_var,
        method = "propensity")
    Condition
      Error in `.validate_formula_variables()`:
      x Variable nonexistent_var not found in `data`.
      i All variables in `formula` must be columns in `data`.
      v Check spelling or add nonexistent_var to the data before calling this function.

# adjust_nonresponse(propensity) errors when formula variable has NA

    Code
      adjust_nonresponse(df, response_status = responded, formula = ~age_group,
        method = "propensity")
    Condition
      Error in `adjust_nonresponse()`:
      x Formula variable age_group contains 1 NA value(s).
      i All formula variables must be fully observed for GLM fitting.
      v Remove or impute NA values in age_group before calling `adjust_nonresponse()`.

