# poststratify() rejects unsupported input class (SE-1)

    Code
      poststratify(matrix(1:4, 2, 2), strata = c(V1), population = pop, type = "count")
    Condition
      Error in `.check_input_class()`:
      x `data` must be a data frame, <weighted_df>, <survey_taylor>, or <survey_nonprob>.
      i Got <matrix>.

# poststratify() rejects 0-row data frame (SE-2)

    Code
      poststratify(df0, strata = c(age_group, sex), population = pop, type = "count")
    Condition
      Error in `poststratify()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# poststratify() rejects survey_replicate input (SE-3)

    Code
      poststratify(rep_obj, strata = c(age_group, sex), population = pop, type = "count")
    Condition
      Error in `.check_input_class()`:
      x <survey_replicate> objects are not supported in Phase 0.
      i Replicate-weight support requires Phase 1.
      v Use a <survey_taylor> design, or wait for Phase 1.

# poststratify() rejects missing named weight column (SE-4)

    Code
      poststratify(df, strata = c(age_group, sex), population = pop, weights = no_such_col,
      type = "count")
    Condition
      Error in `.validate_weights()`:
      x Weight column no_such_col not found in `data`.
      i Available columns: id, age_group, sex, education, region, and base_weight.
      v Pass the column name as a bare name, e.g., `weights = wt_col`.

# poststratify() rejects non-numeric weight column (SE-5)

    Code
      poststratify(df, strata = c(age_group, sex), population = pop, weights = bad_wt,
      type = "count")
    Condition
      Error in `.validate_weights()`:
      x Weight column bad_wt must be numeric.
      i Got <character>.
      v Use `as.numeric(bad_wt)` to convert.

# poststratify() rejects non-positive weight column (SE-6)

    Code
      poststratify(df, strata = c(age_group, sex), population = pop, weights = base_weight,
      type = "count")
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 non-positive value(s).
      i All starting weights must be strictly positive (> 0).
      v Remove or replace non-positive weights before proceeding.

# poststratify() rejects NA weight column (SE-7)

    Code
      poststratify(df, strata = c(age_group, sex), population = pop, weights = base_weight,
      type = "count")
    Condition
      Error in `.validate_weights()`:
      x Weight column base_weight contains 1 NA value(s).
      i Weights must be fully observed.
      v Remove rows with missing weights before proceeding.

# poststratify() empty_data fires before weights_not_found (SE-8)

    Code
      poststratify(df0, strata = c(age_group, sex), population = pop, weights = no_such_col,
      type = "count")
    Condition
      Error in `poststratify()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# poststratify() rejects NA in strata variable

    Code
      poststratify(df, strata = c(age_group, sex), population = pop, type = "count")
    Condition
      Error in `poststratify()`:
      x Strata variable age_group contains 1 NA value(s).
      i NA values in strata variables are not allowed.
      v Remove or impute NA values in age_group before calling `poststratify()`.

# poststratify() rejects prop targets that don't sum to 1

    Code
      poststratify(df, strata = c(age_group, sex), population = pop_bad, type = "prop")
    Condition
      Error in `.validate_population_cells()`:
      x Population targets sum to 0.98, not 1.0.
      i When `type = "prop"`, targets in `population` must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in the target column of `population`.

# poststratify() rejects count targets that are non-positive

    Code
      poststratify(df, strata = c(age_group, sex), population = pop_bad, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Population targets contain 1 non-positive value(s).
      i When `type = "count"`, all targets must be strictly positive (> 0).
      v Remove or correct non-positive entries in the target column of `population`.

# poststratify() rejects duplicate rows in population

    Code
      poststratify(df, strata = c(age_group, sex), population = pop_dup, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Population cell "18-34//M" appears 2 times in `population`.
      i Each cell combination must appear exactly once in `population`.
      v Remove duplicate rows for "18-34//M" from `population` before calling `poststratify()`.

# poststratify() rejects population missing a data cell

    Code
      poststratify(df, strata = c(age_group, sex), population = pop_missing, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Cell "55+//F" is present in `data` but has no matching row in `population`.
      i Every cell combination in the data must appear in `population`.
      v Add a row for "55+//F" to `population`.

# poststratify() rejects population cells absent from data

    Code
      poststratify(df, strata = c(age_group, sex), population = pop_extra, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Population cell "65+//M" has no observations in `data`.
      i Extra cells in the population frame are not allowed -- they may indicate a misspecified population.
      v Remove rows for "65+//M" from `population` before calling `poststratify()`.

# poststratify() rejects population missing the 'target' column

    Code
      poststratify(df, strata = c(age_group), population = pop_no_target, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x `population` is missing required column target.
      i `population` must have columns for each strata variable (age_group) plus target.
      v Add the target column to `population`.

