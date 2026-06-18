# calibrate_to_survey() rejects non-replicate primary_design

    Code
      calibrate_to_survey(taylor, control, variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `primary_design` must be a <survey_replicate> or a <survey_nonprob> with replicate weights, got <surveycore::survey_taylor>.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights before calibrating.

# calibrate_to_survey() rejects non-replicate control_design

    Code
      calibrate_to_survey(primary, taylor, variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `control_design` must be a <survey_replicate> or a <survey_nonprob> with replicate weights, got <surveycore::survey_taylor>.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights.

# calibrate_to_survey() rejects non-taylor reference_design

    Code
      calibrate_to_survey(primary, control, variables = c(sex), reference_design = primary)
    Condition
      Error in `calibrate_to_survey()`:
      x `reference_design` must be a <survey_taylor> or `NULL`, got <surveycore::survey_replicate>.
      i `reference_design` is used for provenance tracking only.

# calibrate_to_survey() rejects invalid unit_scale (non-numeric)

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = "bad")
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 100.

# calibrate_to_survey() rejects unit_scale with wrong length

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = rep(1, 5))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must have length equal to the number of rows in `data`.
      i Got length 5 but expected 100.
      v Supply a positive numeric vector of length 100.

# calibrate_to_survey() rejects unit_scale with NA

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- NA_real_
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must not contain `NA` values.
      i Found 1 `NA` value in `unit_scale`.
      v Remove `NA`s or set `unit_scale = NULL` to use uniform q-weights.

# calibrate_to_survey() rejects unit_scale with non-positive values

    Code
      calibrate_to_survey(primary, control, variables = c(sex), unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- -1
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

# calibrate_to_survey() rejects variables not in primary_design

    Code
      calibrate_to_survey(primary, control, variables = c(nonexistent_var))
    Condition
      Error in `value[[3L]]()`:
      x Calibration variables not found in `primary_design`.
      i Tidy-select error: Can't select columns that don't exist. x Column `nonexistent_var` doesn't exist.

# calibrate_to_estimate() rejects non-replicate design

    Code
      calibrate_to_estimate(taylor, targets, vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `design` must be a <survey_replicate> or a <survey_nonprob> with replicate weights, got <surveycore::survey_taylor>.
      i Replicate weights are required to propagate the uncertainty of the external estimates.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights.

# calibrate_to_estimate() rejects non-taylor reference_design

    Code
      calibrate_to_estimate(primary, targets, vcov_est, reference_design = primary)
    Condition
      Error in `calibrate_to_estimate()`:
      x `reference_design` must be a <survey_taylor> or `NULL`, got <surveycore::survey_replicate>.
      i `reference_design` is used for provenance tracking only.

# calibrate_to_estimate() rejects invalid unit_scale

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = "bad")
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must be a positive numeric vector or `NULL`.
      i Got <character>.
      v Supply a positive numeric vector of length 100.

# calibrate_to_estimate() rejects unit_scale with wrong length

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = rep(1, 5))
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must have length equal to the number of rows in `data`.
      i Got length 5 but expected 100.
      v Supply a positive numeric vector of length 100.

# calibrate_to_estimate() rejects unit_scale with NA

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- NA_real_
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must not contain `NA` values.
      i Found 1 `NA` value in `unit_scale`.
      v Remove `NA`s or set `unit_scale = NULL` to use uniform q-weights.

# calibrate_to_estimate() rejects unit_scale with non-positive values

    Code
      calibrate_to_estimate(primary, targets, vcov_est, unit_scale = {
        us2 <- rep(1, nrow(primary@data))
        us2[1L] <- -1
        us2
      })
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

# calibrate_to_estimate() rejects non-named-list targets

    Code
      calibrate_to_estimate(primary, list(c(60, 40)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `targets` must be a non-empty named list with all elements named.
      i Each name gives the variable in `design@data`, and each element is a named numeric vector of population count totals.

# calibrate_to_estimate() rejects targets element with no names

    Code
      calibrate_to_estimate(primary, list(sex = c(60, 40)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `targets$sex` must be a named numeric vector.
      i Got <numeric> with no names.
      v Supply count totals as e.g. `c(level1 = 1000, level2 = 500)`.

# calibrate_to_estimate() rejects targets element with non-positive values

    Code
      calibrate_to_estimate(primary, list(sex = c(F = 60, M = -1)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `targets$sex` contains 1 value(s) that are NA or not strictly positive.
      i All population count totals must be > 0.

# calibrate_to_estimate() rejects targets variable not in design

    Code
      calibrate_to_estimate(primary, list(nonexistent_var = c(a = 60, b = 40)),
      vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x Calibration variable(s) not found in `design`: nonexistent_var.
      i Available columns: id, age_group, sex, education, region, base_weight, rep_1, rep_2, rep_3, rep_4, rep_5, rep_6, rep_7, rep_8, rep_9, rep_10, rep_11, rep_12, ..., rep_49, and rep_50.

# calibrate_to_estimate() rejects targets levels mismatch

    Code
      calibrate_to_estimate(primary, list(sex = c(Female = 110, Male = 90)), vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x Level labels in `targets$sex` do not exactly match the levels in `design@data$sex`.
      i Levels in data but not in targets: F, M; Levels in targets but not in data: Female, Male

# calibrate_to_estimate() rejects vcov with NA

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` contains 1 NA value(s).
      i The variance-covariance matrix must be fully observed.

# calibrate_to_estimate() rejects vcov with wrong dimensions

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` must be 2 x 2 (one row/column per element of `unlist(targets)`).
      i Got 3 x 3.

# calibrate_to_estimate() rejects non-symmetric vcov

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` is not symmetric: max(|V - V^T|) = 49.
      i Symmetry tolerance is 1e-8.
      v Symmetrize with `(vcov + t(vcov)) / 2`.

# calibrate_to_estimate() rejects non-positive-definite vcov

    Code
      calibrate_to_estimate(primary, targets, vcov_bad)
    Condition
      Error in `calibrate_to_estimate()`:
      x `vcov_estimate` is not positive definite.
      i Cholesky decomposition failed: the leading minor of order 2 is not positive
      v Use a valid variance-covariance matrix (all eigenvalues > 0).

# calibrate_to_estimate() propagates convergence warning as error

    Code
      calibrate_to_estimate(primary, targets, vcov_est)
    Condition
      Error:
      x Calibration to estimate did not converge after 50 iterations.
      i svrep::calibrate_to_estimate() reported: Calibration did not converge
      v Increase `control$maxit`, relax `control$epsilon`, or verify the target counts are consistent with the design.

# calibrate_to_estimate() propagates hard svrep errors

    Code
      calibrate_to_estimate(primary, targets, vcov_est)
    Condition
      Error in `value[[3L]]()`:
      x svrep::calibrate_to_estimate() encountered an error.
      i svrep reported: svrep internal error

# calibrate_to_survey() fires surveywts_error_primary_no_repweights

    Code
      calibrate_to_survey(primary_design = primary_no_rep, control_design = control,
        variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `primary_design` is a <survey_nonprob> but has no replicate weights.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights before calibrating.

# calibrate_to_survey() fires surveywts_error_control_no_repweights

    Code
      calibrate_to_survey(primary_design = primary, control_design = control_no_rep,
        variables = c(sex))
    Condition
      Error in `calibrate_to_survey()`:
      x `control_design` is a <survey_nonprob> but has no replicate weights.
      i Replicate weights are required to propagate control-survey uncertainty.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights.

# calibrate_to_estimate() fires surveywts_error_design_no_repweights

    Code
      calibrate_to_estimate(design_no_rep, targets, vcov_est)
    Condition
      Error in `calibrate_to_estimate()`:
      x `design` is a <survey_nonprob> but has no replicate weights.
      i Replicate weights are required to propagate the uncertainty of the external estimates.
      v Use `create_bootstrap_weights()` or another `create_*_weights()` function to add replicate weights before calibrating.

# calibrate_to_survey() fires scale_not_found when primary@variables$scale is NULL (targets = NULL)

    Code
      p2 <- make_replicate_design(n = 100L, seed = 1L)
      v2 <- p2@variables
      v2$scale <- NULL
      p2@variables <- v2
      calibrate_to_survey(p2, make_replicate_design(n = 100L, seed = 2L), variables = c(
        sex), targets = NULL)
    Condition
      Error in `calibrate_to_survey()`:
      x Replication scale constant not found in `primary_design`.
      i `@variables$scale` must be non-NULL to compute Opsomer `a_r` adjustment constants.
      v Use `create_bootstrap_weights()` to create designs with `@variables$scale` populated.

# calibrate_to_survey() fires scale_not_found when primary@variables$scale is NULL (targets non-NULL)

    Code
      p2a <- make_replicate_design(n = 100L, seed = 1L)
      c2a <- make_replicate_design(n = 100L, seed = 2L)
      v2a <- p2a@variables
      v2a$scale <- NULL
      p2a@variables <- v2a
      calibrate_to_survey(p2a, c2a, variables = c(age_group), targets = list(sex = c(
        M = 0.48, F = 0.52)), type = "prop")
    Condition
      Error in `calibrate_to_survey()`:
      x Replication scale constant not found in `primary_design`.
      i `@variables$scale` must be non-NULL to compute Opsomer `a_r` adjustment constants.
      v Use `create_bootstrap_weights()` to create designs with `@variables$scale` populated.

# calibrate_to_survey() fires scale_not_found when control@variables$scale is NULL (targets non-NULL)

    Code
      p2b <- make_replicate_design(n = 100L, seed = 1L)
      c2b <- make_replicate_design(n = 100L, seed = 2L)
      v2b <- c2b@variables
      v2b$scale <- NULL
      c2b@variables <- v2b
      calibrate_to_survey(p2b, c2b, variables = c(age_group), targets = list(sex = c(
        M = 0.48, F = 0.52)), type = "prop")
    Condition
      Error in `calibrate_to_survey()`:
      x Replication scale constant not found in `control_design`.
      i `@variables$scale` must be non-NULL to compute Opsomer `a_r` adjustment constants.
      v Use `create_bootstrap_weights()` to create designs with `@variables$scale` populated.

# calibrate_to_survey() fires scale_not_found when control@variables$scale is NULL (targets = NULL)

    Code
      p3 <- make_replicate_design(n = 100L, seed = 1L)
      c3 <- make_replicate_design(n = 100L, seed = 2L)
      v3 <- c3@variables
      v3$scale <- NULL
      c3@variables <- v3
      calibrate_to_survey(p3, c3, variables = c(sex), targets = NULL)
    Condition
      Error in `calibrate_to_survey()`:
      x Replication scale constant not found in `control_design`.
      i `@variables$scale` must be non-NULL to compute Opsomer `a_r` adjustment constants.
      v Use `create_bootstrap_weights()` to create designs with `@variables$scale` populated.

# calibrate_to_survey() fires control_level_missing when a level is absent from control (targets = NULL)

    Code
      df_snap <- make_surveywts_data(n = 200L, seed = 77L)
      df_snap_m <- df_snap[df_snap$sex == "M", ]
      t_snap <- surveycore::survey_taylor(data = df_snap_m, variables = list(weights = "base_weight"))
      ctrl_snap <- create_bootstrap_weights(t_snap, replicates = 50L)
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L), ctrl_snap,
      variables = c(sex), targets = NULL)
    Condition
      Error in `.check_control_levels()`:
      x Control survey is missing level(s) of variable sex: "F".
      i All levels in `primary_design` must also appear in `control_design` to estimate control-survey totals.
      v Verify that `control_design` covers the same population as `primary_design`.

# calibrate_to_survey() fires control_level_missing when a level is absent from control (targets non-NULL)

    Code
      df_sn2 <- make_surveywts_data(n = 500L, seed = 88L)
      df_sn2_partial <- df_sn2[df_sn2$age_group != "55+", ]
      t_sn2 <- surveycore::survey_taylor(data = df_sn2_partial, variables = list(
        weights = "base_weight"))
      ctrl_sn2 <- create_bootstrap_weights(t_sn2, replicates = 50L)
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L), ctrl_sn2,
      variables = c(age_group), targets = list(sex = c(M = 0.48, F = 0.52)), type = "prop")
    Condition
      Error in `.check_control_levels()`:
      x Control survey is missing level(s) of variable age_group: "55+".
      i All levels in `primary_design` must also appear in `control_design` to estimate control-survey totals.
      v Verify that `control_design` covers the same population as `primary_design`.

# calibrate_to_survey() fires targets_not_named_list for unnamed element

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(sex), targets = list(
        c(1000, 2000)))
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` has unnamed element(s).
      i Every element of `targets` must be named with a variable name.
      v Pass a named list, e.g. `list(age_group = c('18-34' = 0.30, ...))`.

# calibrate_to_survey() fires targets_not_named_list for empty list

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(sex), targets = list())
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` is an empty list.
      i Every element of `targets` must be named with a variable name.
      v Pass a named list, e.g. `list(age_group = c('18-34' = 0.30, ...))`.

# calibrate_to_survey() fires targets_not_named_list when targets is not a list

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(sex), targets = c(
        age = 1000))
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` must be a named list, got <numeric>.
      i Each element name is a variable in `primary_design`.
      v Pass a named list, e.g. `list(age_group = c('18-34' = 0.30, ...))`.

# calibrate_to_survey() fires targets_variable_not_found for nonexistent column

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(sex), targets = list(
        nonexistent_col = c(a = 100)))
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "nonexistent_col" is not a column in `primary_design`.
      i Available columns: id, age_group, sex, education, region, base_weight, rep_1, rep_2, rep_3, rep_4, rep_5, rep_6, rep_7, rep_8, rep_9, rep_10, rep_11, rep_12, ..., rep_49, and rep_50.

# calibrate_to_survey() fires targets_element_invalid for string element

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(age_group), targets = list(
        sex = "not_a_vector"), type = "count")
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "sex" is not a valid format.
      i Expected a named numeric vector or a tibble with a sex column plus n or prop.
      v E.g. `c('18-34' = 0.30, '35-54' = 0.40)` or `tibble(sex = ..., prop = ...)`.

# calibrate_to_survey() fires targets_element_invalid for unnamed numeric vector

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(age_group), targets = list(
        sex = c(100, 200)), type = "count")
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "sex" is not a valid format.
      i Expected a named numeric vector or a tibble with a sex column plus n or prop.
      v E.g. `c('18-34' = 0.30, '35-54' = 0.40)` or `tibble(sex = ..., prop = ...)`.

# calibrate_to_survey() fires targets_totals_invalid for count = 0

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(age_group), targets = list(
        sex = c(M = 0, F = 200)), type = "count")
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "sex" has invalid count(s).
      i With `type = "count"`, all values must be positive and non-NA.
      v Fix the value(s) in `targets[["sex"]]`.

# calibrate_to_survey() fires targets_totals_invalid for count < 0

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(age_group), targets = list(
        sex = c(M = -50, F = 200)), type = "count")
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "sex" has invalid count(s).
      i With `type = "count"`, all values must be positive and non-NA.
      v Fix the value(s) in `targets[["sex"]]`.

# calibrate_to_survey() fires targets_totals_invalid for count = NA

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(age_group), targets = list(
        sex = c(M = NA_real_, F = 200)), type = "count")
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "sex" has invalid count(s).
      i With `type = "count"`, all values must be positive and non-NA.
      v Fix the value(s) in `targets[["sex"]]`.

# calibrate_to_survey() fires targets_totals_invalid when prop sum != 1

    Code
      calibrate_to_survey(make_replicate_design(n = 100L, seed = 1L),
      make_replicate_design(n = 100L, seed = 2L), variables = c(age_group), targets = list(
        sex = c(M = 0.6, F = 0.5)), type = "prop")
    Condition
      Error in `.validate_targets_for_opsomer()`:
      x `targets` element "sex" proportions sum to 1.1, not 1.
      i With `type = "prop"`, values must sum to exactly 1 (within 1e-6).
      v Rescale or correct the values in `targets[["sex"]]`.

