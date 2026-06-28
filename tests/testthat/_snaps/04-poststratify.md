# poststratify() aborts with cli error for data.frame input

    Code
      poststratify(make_surveywts_data(), targets = pop, type = "count")
    Condition
      Error in `.check_input_class()`:
      x `data` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <data.frame>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# poststratify() rejects unsupported input class (SE-1)

    Code
      poststratify(list(x = 1), targets = pop, type = "count")
    Condition
      Error in `.check_input_class()`:
      x `data` must be a <survey_nonprob>, <survey_taylor>, or <survey_replicate>.
      i Got <list>.
      v Use `surveycore::as_survey_nonprob()`, `surveycore::as_survey()`, or `surveycore::as_survey_replicate()` to construct a survey object.

# poststratify() rejects 0-row survey_taylor (SE-3)

    Code
      poststratify(design0, targets = pop, type = "count")
    Condition
      Error in `poststratify()`:
      x `data` has 0 rows.
      i This operation is undefined on empty data.
      v Ensure `data` has at least one row.

# poststratify() rejects non-character wt_name

    Code
      poststratify(design, targets = pop, type = "count", wt_name = 42)
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a single character string.
      i Got <numeric> of length 1.

# poststratify() rejects empty wt_name

    Code
      poststratify(design, targets = pop, type = "count", wt_name = "")
    Condition
      Error in `.validate_wt_name()`:
      x `wt_name` must be a non-empty, non-NA string.

# poststratify() rejects non-taylor reference_design

    Code
      poststratify(design, targets = pop, type = "count", reference_design = list(x = 1))
    Condition
      Error in `.validate_reference_design()`:
      x `reference_design` must be a <survey_taylor>.
      i Got class <list>.
      v Pass the <survey_taylor> object used to compute the targets.

# poststratify() rejects targets that is not a data.frame

    Code
      poststratify(design, targets = bad_targets, type = "prop")
    Condition
      Error in `poststratify()`:
      x `targets` must be a <data.frame> with one column per stratification variable and one column named target.
      i Got <list>.
      v Pass a <data.frame> where non-target columns define the strata cells.

# poststratify() rejects targets with zero strata columns

    Code
      poststratify(design, targets = targets_bad, type = "prop")
    Condition
      Error in `poststratify()`:
      x `targets` has no stratification variable columns (only a target column was found).
      i Stratification variables are identified as all columns in `targets` except target.
      v Add at least one column to `targets` that matches a column in `data`.

# poststratify() rejects targets with column absent from data

    Code
      poststratify(design, targets = targets_bad, type = "prop")
    Condition
      Error in `poststratify()`:
      x Stratification variable no_such_col from `targets` not found in `data`.
      i Non-target column names in `targets` must match column names in `data`.
      v Check spelling: available columns are id, age_group, sex, education, region, and base_weight.

# poststratify() rejects NA in strata variable

    Code
      poststratify(design, targets = pop, type = "count")
    Condition
      Error in `poststratify()`:
      x Strata variable age_group contains 1 NA value(s).
      i NA values in strata variables are not allowed.
      v Remove or impute NA values in age_group before calling `poststratify()`.

# poststratify() rejects prop targets that don't sum to 1

    Code
      poststratify(design, targets = pop_bad, type = "prop")
    Condition
      Error in `.validate_population_cells()`:
      x Population targets sum to 0.98, not 1.0.
      i When `type = "prop"`, targets in `targets` must sum to 1.0 (within 1e-6 tolerance).
      v Adjust the values in the target column of `targets`.

# poststratify() rejects count targets that are non-positive

    Code
      poststratify(design, targets = pop_bad, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Population targets contain 1 non-positive value(s).
      i When `type = "count"`, all targets must be strictly positive (> 0).
      v Remove or correct non-positive entries in the target column of `targets`.

# poststratify() rejects duplicate rows in targets

    Code
      poststratify(design, targets = pop_dup, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Population cell "18-34//M" appears 2 times in `targets`.
      i Each cell combination must appear exactly once in `targets`.
      v Remove duplicate rows for "18-34//M" from `targets` before calling `poststratify()`.

# poststratify() rejects targets missing a data cell

    Code
      poststratify(design, targets = pop_missing, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Cell "55+//F" is present in `data` but has no matching row in `targets`.
      i Every cell combination in the data must appear in `targets`.
      v Add a row for "55+//F" to `targets`.

# poststratify() rejects targets missing the 'target' column

    Code
      poststratify(design, targets = pop_no_target, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x `targets` is missing required column target.
      i `targets` must have columns for each strata variable (age_group) plus target.
      v Add the target column to `targets`.

# poststratify() rejects targets cells absent from data

    Code
      poststratify(design, targets = pop_extra, type = "count")
    Condition
      Error in `.validate_population_cells()`:
      x Population cell "65+//M" has no observations in `data`.
      i Extra cells in `targets` are not allowed -- they may indicate a misspecified population.
      v Remove rows for "65+//M" from `targets` before calling `poststratify()`.

